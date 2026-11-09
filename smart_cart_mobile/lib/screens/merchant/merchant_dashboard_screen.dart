import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/order_model.dart';
import '../../models/inventory_model.dart';
import '../../models/user_model.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _orders = [];
  List<InventoryItemModel> _inventory = [];
  bool _isLoadingOrders = false;
  bool _isLoadingInventory = false;
  String _selectedCategory = 'All';
  Timer? _pollTimer;
  int _activeStoreId = 1;

  static const List<Map<String, dynamic>> _allMerchantStores = [
    {
      'store_id': 1,
      'merchant_id': 3,
      'name': 'Navjeevan Supermart',
      'owner': 'Navjeevan Retail Ltd',
      'user_id': 'MERC2001',
      'phone': '9845012345',
      'email': 'support@navjeevan.in',
      'address': '#45, Navjeevan Complex, 100 Feet Road, Indiranagar, Bengaluru',
      'upi': 'navjeevan@okaxis',
      'rating': '4.9',
      'gradient': [Color(0xFFD97706), Color(0xFFB45309)],
      'badge': 'NAVJEEVAN SUPERMART',
    },
    {
      'store_id': 2,
      'merchant_id': 4,
      'name': 'More Provision',
      'owner': 'More Retail (More Provision)',
      'user_id': 'MERC2002',
      'phone': '9845098765',
      'email': 'contact@moreprovision.com',
      'address': '#12, More Provision Store, CMH Road, Indiranagar, Bengaluru',
      'upi': 'moreprovision@okhdfcbank',
      'rating': '4.8',
      'gradient': [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
      'badge': 'MORE PROVISION STORE',
    },
  ];

  Map<String, dynamic> get _activeStoreData {
    return _allMerchantStores.firstWhere(
      (s) => s['store_id'] == _activeStoreId,
      orElse: () => _allMerchantStores.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = ApiService().currentUser;
    if (user != null && user.storeName != null && user.storeName!.toLowerCase().contains('more')) {
      _activeStoreId = 2;
    } else {
      _activeStoreId = 1;
    }
    _ensureUserMatchesActiveStore();
    _loadOrders();
    _loadInventory();
    _startAutoPolling();
  }

  void _ensureUserMatchesActiveStore() {
    final storeData = _activeStoreData;
    final current = ApiService().currentUser;
    if (current == null || current.id != storeData['merchant_id']) {
      ApiService().currentUser = UserModel(
        id: storeData['merchant_id'] as int,
        userId: storeData['user_id'] as String,
        name: '${storeData['name']} Manager',
        mobile: storeData['phone'] as String,
        email: storeData['email'] as String,
        role: 'merchant',
        address: storeData['address'] as String,
        area: 'Indiranagar',
        pincode: '560038',
        storeName: storeData['name'] as String,
        upiId: storeData['upi'] as String,
      );
    }
  }

  void _switchStore(int newStoreId) {
    if (_activeStoreId == newStoreId) return;
    setState(() {
      _activeStoreId = newStoreId;
    });
    _ensureUserMatchesActiveStore();
    _loadOrders();
    _loadInventory();

    final storeData = _activeStoreData;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Switched to ${storeData['name']} Dashboard'),
          ],
        ),
        backgroundColor: newStoreId == 2 ? const Color(0xFF1D4ED8) : const Color(0xFFD97706),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startAutoPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      _loadOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final storeData = _activeStoreData;
    final merchantId = storeData['merchant_id'] as int;
    if (!silent) setState(() => _isLoadingOrders = true);
    try {
      final list = await ApiService().fetchMerchantOrders(merchantId, storeId: _activeStoreId);
      if (mounted) setState(() => _orders = list);
    } catch (e) {
      if (!silent) debugPrint('Error loading merchant orders: $e');
    } finally {
      if (mounted && !silent) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _loadInventory() async {
    final storeData = _activeStoreData;
    final merchantId = storeData['merchant_id'] as int;
    setState(() => _isLoadingInventory = true);
    try {
      final list = await ApiService().fetchMerchantInventory(merchantId, storeId: _activeStoreId, category: _selectedCategory);
      setState(() => _inventory = list);
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

  void _openPackAndConfirmDialog(OrderModel order) {
    final user = ApiService().currentUser;
    if (user == null) return;

    // Create mutable working copy of items
    List<Map<String, dynamic>> workingItems = order.items.map((it) {
      return {
        'item_id': it.id,
        'product_name': it.productName,
        'brand': it.brand,
        'requested_quantity': it.requestedQuantity,
        'unit': it.unit,
        'packed_quantity': it.packedQuantity > 0 ? it.packedQuantity : it.requestedQuantity,
        'unit_price': it.unitPrice > 0 ? it.unitPrice : 40.0,
        'is_available': it.isAvailable,
      };
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double total = 0.0;
          for (var it in workingItems) {
            if (it['is_available'] == true) {
              total += ((it['packed_quantity'] as num) * (it['unit_price'] as num)).toDouble();
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.checklist_rtl_rounded, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check Stock & Bill: ${order.orderNumber}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Check item availability on your store shelves and confirm prices:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.done_all_rounded, size: 14),
                            label: const Text('All In Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setModalState(() {
                                for (var it in workingItems) {
                                  it['is_available'] = true;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Reset Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setModalState(() {
                                for (var it in workingItems) {
                                  it['packed_quantity'] = it['requested_quantity'];
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...workingItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isAvail = item['is_available'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAvail ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAvail ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: isAvail,
                                  activeColor: const Color(0xFF059669),
                                  onChanged: (val) {
                                    setModalState(() {
                                      workingItems[idx]['is_available'] = val;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['product_name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          decoration: isAvail ? null : TextDecoration.lineThrough,
                                          color: isAvail ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        isAvail ? 'In Stock' : 'Out of Stock',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isAvail ? const Color(0xFF059669) : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAvail)
                                  Text(
                                    '₹${((item['packed_quantity'] as num) * (item['unit_price'] as num)).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF059669)),
                                  ),
                              ],
                            ),
                            if (isAvail) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item['packed_quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Qty (${item['unit']})',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (val) {
                                        final q = double.tryParse(val) ?? 1.0;
                                        setModalState(() {
                                          workingItems[idx]['packed_quantity'] = q;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item['unit_price'].toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Rate (₹)',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (val) {
                                        final p = double.tryParse(val) ?? 0.0;
                                        setModalState(() {
                                          workingItems[idx]['unit_price'] = p;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Confirmed Bill:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Bill to Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService().packAndConfirmOrder(user.id, order.id, workingItems, total);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Bill of ₹${total.toStringAsFixed(2)} sent to customer!'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                    _loadOrders();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleStock(InventoryItemModel item, bool newValue) async {
    final user = ApiService().currentUser;
    if (user == null) return;
    setState(() => item.isInStock = newValue);
    try {
      await ApiService().updateInventoryItem(user.id, item.id, {'is_in_stock': newValue});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newValue ? '${item.name} marked IN STOCK' : '${item.name} marked OUT OF STOCK'), duration: const Duration(seconds: 1)),
      );
    } catch (e) {
      setState(() => item.isInStock = !newValue); // rollback
    }
  }

  Future<void> _deleteItem(InventoryItemModel item) async {
    final user = ApiService().currentUser;
    if (user == null) return;
    try {
      await ApiService().deleteInventoryItem(user.id, item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} deleted')),
      );
      _loadInventory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _showEditProductDialog(InventoryItemModel item) {
    final priceCtrl = TextEditingController(text: item.price.toStringAsFixed(2));
    final stockCtrl = TextEditingController(text: item.stockQuantity.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Update Price & Stock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.brand} • ${item.category}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(height: 20),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price per ${item.unit} (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: 'Changing price updates customer view instantly',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Available Stock Quantity (${item.unit})',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final user = ApiService().currentUser;
              if (user == null) return;
              final newPrice = double.tryParse(priceCtrl.text.trim());
              final newStock = double.tryParse(stockCtrl.text.trim());

              if (newPrice == null || newPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price')),
                );
                return;
              }

              try {
                await ApiService().updateInventoryItem(user.id, item.id, {
                  'price': newPrice,
                  'stock_quantity': newStock ?? item.stockQuantity,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated ${item.name} rate to ₹${newPrice.toStringAsFixed(2)}/${item.unit}!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
                _loadInventory();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'Standard');
    final priceCtrl = TextEditingController(text: '50');
    String category = 'Flour & Grains';
    String unit = 'kg';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Add Store Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name (e.g. Besan 1kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(labelText: 'Brand (e.g. Tata, Fortune)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                        items: ['kg', 'l', 'packet', 'piece', 'g', 'box']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => unit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Flour & Grains', 'Oils & Ghee', 'Pulses & Dals', 'Dairy & Bread', 'Spices & Seasoning', 'Beverages', 'Snacks & Instant', 'General']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                final user = ApiService().currentUser;
                if (user == null || nameCtrl.text.trim().isEmpty) return;

                try {
                  await ApiService().addInventoryItem(user.id, {
                    'name': nameCtrl.text.trim(),
                    'brand': brandCtrl.text.trim(),
                    'category': category,
                    'price': double.tryParse(priceCtrl.text) ?? 50.0,
                    'unit': unit,
                    'stock_quantity': 50.0,
                    'is_in_stock': true,
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product added successfully!'), backgroundColor: Color(0xFF059669)),
                  );
                  _loadInventory();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              child: const Text('Add to Store'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpiSettingsDialog(BuildContext context) {
    final user = ApiService().currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: user.upiId ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Store UPI Payment VPA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your store\'s official UPI Virtual Payment Address (VPA). This will generate dynamic QR codes and instant payment links for customer orders.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'UPI ID / VPA',
                hintText: 'e.g. yourshop@okhdfcbank or phone@paytm',
                prefixIcon: const Icon(Icons.payment_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported handles: @okaxis, @okhdfcbank, @okicici, @paytm, @ybl, etc.',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newUpi = controller.text.trim();
              if (newUpi.isEmpty || !newUpi.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid UPI ID containing "@" (e.g. shop@okaxis)')),
                );
                return;
              }
              try {
                await ApiService().updateProfile(user.id, {'upi_id': newUpi});
                ApiService().currentUser = UserModel(
                  id: user.id,
                  userId: user.userId,
                  name: user.name,
                  mobile: user.mobile,
                  email: user.email,
                  role: user.role,
                  address: user.address,
                  area: user.area,
                  pincode: user.pincode,
                  storeName: user.storeName,
                  upiId: newUpi,
                  vehicleType: user.vehicleType,
                  vehicleNumber: user.vehicleNumber,
                  isOnline: user.isOnline,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Store UPI ID updated to $newUpi'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update UPI ID: $e')),
                  );
                }
              }
            },
            child: const Text('Save UPI ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSwitcherBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store 1: Navjeevan Supermart
          Expanded(
            child: InkWell(
              onTap: () => _switchStore(1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: _activeStoreId == 1 ? const Color(0xFFD97706) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeStoreId == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 15,
                          color: _activeStoreId == 1 ? Colors.white : const Color(0xFF92400E),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Navjeevan Supermart',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _activeStoreId == 1 ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '100 Feet Rd • ★ 4.9',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _activeStoreId == 1 ? const Color(0xFFFEF3C7) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Store 2: More Provision
          Expanded(
            child: InkWell(
              onTap: () => _switchStore(2),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: _activeStoreId == 2 ? const Color(0xFF1D4ED8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeStoreId == 2
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 15,
                          color: _activeStoreId == 2 ? Colors.white : const Color(0xFF1E40AF),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'More Provision',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _activeStoreId == 2 ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CMH Road • ★ 4.8',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _activeStoreId == 2 ? const Color(0xFFDBEAFE) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeData = _activeStoreData;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  storeData['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: _activeStoreId == 1 ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                foregroundColor: _activeStoreId == 1 ? const Color(0xFF1D4ED8) : const Color(0xFFD97706),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: Text(
                _activeStoreId == 1 ? 'Go to More Provision' : 'Go to Navjeevan',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _switchStore(_activeStoreId == 1 ? 2 : 1),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_rounded, color: Color(0xFF059669)),
              tooltip: 'Store UPI / QR Settings',
              onPressed: () => _showUpiSettingsDialog(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF059669),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF059669),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Customer Orders'),
              Tab(icon: Icon(Icons.inventory_2_rounded, size: 20), text: 'Inventory & Brands'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildInventoryTab(),
        ],
      ),
    );
  }

  Widget _buildMerchantStatChip(String title, String count, IconData icon, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFDC2626) : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    final storeData = _activeStoreData;
    final gradientColors = storeData['gradient'] as List<Color>;
    final pendingCount = _orders.where((o) => o.status == 'PENDING_MERCHANT').length;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Dual Store Switcher Bar (Navjeevan & More Provision)
          _buildStoreSwitcherBar(),

          // 2. Store Operations Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('🏪 ${storeData['badge']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: gradientColors[0]),
                          const SizedBox(width: 4),
                          Text('${storeData['rating']} Rating', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gradientColors[0])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  storeData['name'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${storeData['address']} • UPI: ${storeData['upi']}',
                  style: const TextStyle(color: Color(0xFFFEF3C7), fontSize: 11),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMerchantStatChip('Total Orders', '${_orders.length}', Icons.receipt_long_rounded),
                    const SizedBox(width: 8),
                    _buildMerchantStatChip(
                      'Pending Pack',
                      '$pendingCount',
                      Icons.pending_actions_rounded,
                      isAlert: pendingCount > 0,
                    ),
                    const SizedBox(width: 8),
                    _buildMerchantStatChip(
                      'Active Store',
                      _activeStoreId == 1 ? 'Navjeevan' : 'More Prov.',
                      Icons.storefront_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildMerchantStatChip('Catalog Items', '${_inventory.length}', Icons.inventory_2_rounded),
                  ],
                ),
              ],
            ),
          ),

          // Action Shortcuts
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _showAddProductDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                  label: const Text('Store UPI QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showUpiSettingsDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text('No incoming orders right now. When customers place orders, they appear here live!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                const Text('Live Customer Orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_orders.length} orders', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ..._orders.map((order) {
              final isPending = order.status == 'PENDING_MERCHANT';

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPending ? Colors.amber.shade100 : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          order.status.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPending ? Colors.amber.shade900 : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Drop: ${order.deliveryAddress}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.paymentMode == 'UPI' ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: order.paymentMode == 'UPI' ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          order.paymentMode == 'UPI' ? '📱 UPI' : '💵 COD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.paymentMode == 'UPI' ? Colors.blue.shade800 : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Dates & Lifecycle Timestamps
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              'Customer Requested: ${order.createdAt.isNotEmpty ? order.createdAt : "Earlier"}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        if (order.confirmedAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '• Store Packed: ${order.confirmedAt}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (order.dispatchedAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '• Dispatched to Delivery: ${order.dispatchedAt}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (order.deliveredAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '• Delivered: ${order.deliveredAt}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Divider(height: 14),

                  // Items Checklist
                  const Text('Requested Grocery Items:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...order.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(it.productName, style: const TextStyle(fontSize: 12))),
                        Text('${it.requestedQuantity} ${it.unit}  •  ₹${it.unitPrice}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),

                  if (isPending)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 16),
                            label: const Text('⚡ Quick Confirm (All In-Stock)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              try {
                                await ApiService().quickConfirmOrder(order.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('⚡ Order ${order.orderNumber} confirmed & bill sent to customer!'),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                }
                                _loadOrders();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Adjust', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _openPackAndConfirmDialog(order),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Confirmed Bill: ₹${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: order.deliveryPartnerName != null ? const Color(0xFFD1FAE5) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.deliveryPartnerName != null ? '🛵 ${order.deliveryPartnerName}' : '⚡ Broadcast Sent',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: order.deliveryPartnerName != null ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (order.deliveryPartnerName == null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('🛵 Alert Nearest Delivery Riders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚡ Instant pickup notification broadcasted to all riders in area!'),
                                  backgroundColor: Color(0xFF2563EB),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    ],
  ),
);
}

  Widget _buildInventoryTab() {
    return Column(
      children: [
        // Dual Store Switcher Bar at top of Inventory
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildStoreSwitcherBar(),
        ),
        // Category Filter & Add Item Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: ['All', 'Flour & Grains', 'Oils & Ghee', 'Pulses & Dals', 'Dairy & Bread', 'Spices & Seasoning', 'Beverages', 'Snacks & Instant', 'General']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                      _loadInventory();
                    }
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loadInventory),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('+ Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showAddProductDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _isLoadingInventory
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _inventory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = _inventory[idx];
                    return InkWell(
                      onTap: () => _showEditProductDialog(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text('${item.brand} • ${item.category} • ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        '₹${item.price.toStringAsFixed(2)}/${item.unit}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF059669)),
                              tooltip: 'Edit Price & Stock',
                              onPressed: () => _showEditProductDialog(item),
                            ),
                            Switch(
                              value: item.isInStock,
                              activeColor: const Color(0xFF059669),
                              onChanged: (val) => _toggleStock(item, val),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                              onPressed: () => _deleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
