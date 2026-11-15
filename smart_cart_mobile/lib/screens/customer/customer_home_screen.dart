import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/camera/camera_capture_service.dart';
import '../../models/ocr_result_model.dart';
import '../../models/store_model.dart';
import '../../models/order_model.dart';
import '../../services/navigation/url_launcher_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback onRefreshNeeded;

  const CustomerHomeScreen({Key? key, required this.onRefreshNeeded}) : super(key: key);

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingOcr = false;
  OcrResultModel? _ocrResult;

  List<StoreModel> _stores = [];
  StoreModel? _selectedStore;
  Map<String, dynamic>? _availabilityData;
  List<Map<String, dynamic>> _storeComparisons = [];
  bool _isComparingStores = false;

  OrderModel? _activeOrder;
  String _checkoutPaymentPreference = 'COD';
  Timer? _orderPollingTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startOrderPolling();
  }

  void _startOrderPolling() {
    _orderPollingTimer?.cancel();
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final user = ApiService().currentUser;
      if (user != null && _activeOrder != null && _activeOrder!.status != 'DELIVERED') {
        _loadActiveOrder(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _orderPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadStores();
    await _loadActiveOrder();
  }

  Future<void> _loadStores() async {
    try {
      final list = await ApiService().fetchStores();
      setState(() {
        _stores = list;
        if (list.isNotEmpty && _selectedStore == null) {
          _selectedStore = list.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }

  Future<void> _loadActiveOrder({bool silent = false}) async {
    final user = ApiService().currentUser;
    if (user == null) return;
    try {
      final order = await ApiService().fetchCustomerActiveOrder(user.id);
      if (mounted) {
        setState(() => _activeOrder = order);
      }
    } catch (e) {
      if (!silent) debugPrint('Error loading active order: $e');
    }
  }

  Future<void> _openLiveCamera() async {
    try {
      final bytes = await CameraCaptureService.capturePhotoFromLiveCamera();
      if (bytes == null) {
        return; // User cancelled / closed camera
      }

      setState(() => _isProcessingOcr = true);
      final res = await ApiService().ocrUploadBytes(bytes, 'camera_scan.jpg');

      setState(() {
        _ocrResult = res;
      });

      if (_ocrResult != null && _ocrResult!.items.isNotEmpty) {
        await _checkAvailability();
        await _compareStores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _submitCustomText(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessingOcr = true);
    try {
      final res = await ApiService().ocrUploadText(text.trim());
      setState(() {
        _ocrResult = res;
      });
      if (_ocrResult != null && _ocrResult!.items.isNotEmpty) {
        await _checkAvailability();
        await _compareStores();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process text: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (photo == null) return;

      setState(() => _isProcessingOcr = true);
      final bytes = await photo.readAsBytes();
      final res = await ApiService().ocrUploadBytes(bytes, photo.name);

      setState(() {
        _ocrResult = res;
      });

      if (_ocrResult != null && _ocrResult!.items.isNotEmpty) {
        await _checkAvailability();
        await _compareStores();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _usePreset(String presetKey) async {
    setState(() => _isProcessingOcr = true);
    try {
      final res = await ApiService().ocrUploadPreset(presetKey);
      setState(() {
        _ocrResult = res;
      });
      if (_ocrResult != null && _ocrResult!.items.isNotEmpty) {
        await _checkAvailability();
        await _compareStores();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load preset: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (_selectedStore == null || _ocrResult == null || _ocrResult!.items.isEmpty) return;
    try {
      final res = await ApiService().checkAvailability(_selectedStore!.id, _ocrResult!.items);
      setState(() => _availabilityData = res);
    } catch (e) {
      debugPrint('Availability check error: $e');
    }
  }

  Future<void> _compareStores() async {
    if (_ocrResult == null || _ocrResult!.items.isEmpty) return;
    setState(() => _isComparingStores = true);
    try {
      final user = ApiService().currentUser;
      final res = await ApiService().compareAllStores(_ocrResult!.items, area: user?.area);
      if (res['status'] == 'success') {
        final list = List<Map<String, dynamic>>.from(res['comparisons'] ?? []);
        setState(() {
          _storeComparisons = list;
          // If no store selected or recommended store exists, select the top recommended one
          if (_selectedStore == null && list.isNotEmpty) {
            final recId = res['recommended_store_id'];
            final recMatch = _stores.firstWhere((s) => s.id == recId, orElse: () => _stores.first);
            _selectedStore = recMatch;
            _checkAvailability();
          }
        });
      }
    } catch (e) {
      debugPrint('Store comparison error: $e');
    } finally {
      if (mounted) setState(() => _isComparingStores = false);
    }
  }

  void _selectStoreAndRecalculate(StoreModel store) {
    setState(() {
      _selectedStore = store;
    });
    _checkAvailability();
  }

  Future<void> _submitOrderToMerchant() async {
    final user = ApiService().currentUser;
    if (user == null || _selectedStore == null || _ocrResult == null || _ocrResult!.items.isEmpty) return;

    try {
      final res = await ApiService().createOrder(
        user.id,
        _selectedStore!.id,
        _ocrResult!.items,
        user.address,
        paymentMode: _checkoutPaymentPreference,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Order sent to merchant for packing!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      setState(() {
        _ocrResult = null;
        _availabilityData = null;
        _storeComparisons = [];
      });
      _loadActiveOrder();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit order: $e')),
      );
    }
  }

  Future<void> _acceptOrder(String paymentMode, {String? transactionRef}) async {
    final user = ApiService().currentUser;
    if (user == null || _activeOrder == null) return;

    try {
      final res = await ApiService().acceptMerchantPacking(
        user.id,
        _activeOrder!.id,
        paymentMode,
        transactionRef: transactionRef,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentMode == 'UPI'
                ? 'UPI Payment verified! Your 6-digit delivery OTP code: ${res['delivery_code']}'
                : 'COD Confirmed! Your 6-digit delivery OTP code: ${res['delivery_code']}'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      _loadActiveOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept order: $e')),
        );
      }
    }
  }

  void _updateItemQuantity(int index, double delta) {
    if (_ocrResult == null || index >= _ocrResult!.items.length) return;
    setState(() {
      final current = _ocrResult!.items[index].quantity;
      double updated = current + delta;
      if (updated <= 0.0) {
        _ocrResult!.items.removeAt(index);
      } else {
        _ocrResult!.items[index].quantity = double.parse(updated.toStringAsFixed(1));
      }
    });
    _checkAvailability();
    _compareStores();
  }

  void _showEditItemDialog(int index) {
    if (_ocrResult == null || index >= _ocrResult!.items.length) return;
    final item = _ocrResult!.items[index];
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(text: item.quantity.toString());
    String selectedUnit = item.unit;
    final unitOptions = ['kg', 'g', 'l', 'ml', 'packet', 'piece', 'bottle', 'box'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Edit Item Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: unitOptions.contains(selectedUnit) ? selectedUnit : 'packet',
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedUnit = val);
                      },
                    ),
                  ),
                ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final newName = nameController.text.trim();
                final newQty = double.tryParse(qtyController.text.trim()) ?? item.quantity;
                if (newName.isNotEmpty) {
                  setState(() {
                    item.name = newName;
                    item.quantity = newQty;
                    item.unit = selectedUnit;
                  });
                  _checkAvailability();
                  _compareStores();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    String selectedUnit = 'kg';
    final unitOptions = ['kg', 'g', 'l', 'ml', 'packet', 'piece', 'bottle', 'box'];
    final quickSuggestions = ['Aashirvaad Atta', 'Madhur Sugar', 'Tata Salt', 'Amul Milk', 'Fortune Mustard Oil', 'Toor Dal', 'Maggi Noodles', 'Fresh Eggs', 'White Bread', 'Dettol Soap'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Add Grocery Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g. Atta, Sugar, Milk, Bread, Dal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Popular Staples:', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: quickSuggestions.map((s) => ActionChip(
                    padding: EdgeInsets.zero,
                    label: Text(s, style: const TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDialogState(() {
                        nameController.text = s;
                        if (s.contains('Milk') || s.contains('Noodles') || s.contains('Bread')) {
                          selectedUnit = 'packet';
                        } else if (s.contains('Oil')) {
                          selectedUnit = 'l';
                        } else if (s.contains('Eggs') || s.contains('Soap')) {
                          selectedUnit = 'piece';
                        } else {
                          selectedUnit = 'kg';
                        }
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedUnit = val);
                        },
                      ),
                    ),
                  ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final qty = double.tryParse(qtyController.text.trim()) ?? 1.0;
                if (name.isNotEmpty) {
                  setState(() {
                    if (_ocrResult == null) {
                      _ocrResult = OcrResultModel(rawText: name, items: []);
                    }
                    _ocrResult!.items.add(ExtractedGroceryItem(
                      name: name,
                      brand: 'Standard',
                      quantity: qty,
                      unit: selectedUnit,
                      category: 'Pantry',
                      confidence: 0.99,
                    ));
                  });
                  _checkAvailability();
                  _compareStores();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add to List'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualTextDialog([String? initialText]) {
    final controller = TextEditingController(
      text: initialText ?? 'Atta 5kg\nSugar 2kg\nMustard Oil 1L\nTata Salt 1kg\nMilk 2 packets\nMaggi 4pkt',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Enter Grocery List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type or paste your grocery items (one per line with quantity):',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'e.g.\nAtta 5kg\nSugar 1kg\nMilk 2 packets\nToor dal 500gm\nMaggi 4pkt',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitCustomText(controller.text);
            },
            child: const Text('Scan & Check Local Stores'),
          ),
        ],
      ),
    );
  }

  void _showUpiPaymentSheet(OrderModel order) {
    final utrController = TextEditingController();
    final storeUpi = (order.storeUpiId != null && order.storeUpiId!.isNotEmpty)
        ? order.storeUpiId!
        : (_selectedStore?.upiId ?? 'navjeevan@okaxis');
    final amountStr = order.totalAmount.toStringAsFixed(2);
    final upiUriString = (order.upiUri != null && order.upiUri!.isNotEmpty)
        ? order.upiUri!
        : 'upi://pay?pa=$storeUpi&pn=${Uri.encodeComponent(order.storeName)}&am=$amountStr&cu=INR&tn=SmartCart%20${order.orderNumber}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.blue, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pay via UPI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Direct payment to ${order.storeName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₹$amountStr',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dynamic Store UPI QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        if (order.upiQrCode != null && order.upiQrCode!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(order.upiQrCode!.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                              width: 190,
                              height: 190,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(
                                width: 190,
                                height: 190,
                                child: Center(
                                  child: Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF059669)),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(
                            width: 190,
                            height: 190,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_strong_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text(
                              'Scan with GPay / PhonePe / Paytm / BHIM',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Direct UPI App Launch Button (Native Intent for Android / Web)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    '🚀 Open Installed UPI App (GPay / PhonePe / Paytm)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    final launched = await launchUpiIntent(upiUriString);
                    if (!launched && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UPI intent opened. If no external app responded, please scan the QR code above or tap 1-Tap Instant Payment.'),
                          backgroundColor: Color(0xFF2563EB),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Store UPI ID Copy Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.blueGrey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STORE UPI ID / VPA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)),
                            Text(storeUpi, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF059669)),
                        tooltip: 'Copy UPI ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: storeUpi));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('UPI ID copied to clipboard!'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Clickable Quick-Launch Chips
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildUpiAppChip('Google Pay', upiUriString),
                    _buildUpiAppChip('PhonePe', upiUriString),
                    _buildUpiAppChip('Paytm', upiUriString),
                    _buildUpiAppChip('BHIM UPI', upiUriString),
                  ],
                ),
                const SizedBox(height: 16),

                // 1-Tap Instant Payment Simulator for Evaluators & Instant Checkout
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text(
                    '⚡ 1-Tap Instant Payment (Instant Verification)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final simRef = 'UPI-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                    _acceptOrder('UPI', transactionRef: simRef);
                  },
                ),
                const SizedBox(height: 12),

                // Manual UTR Entry Fallback
                TextField(
                  controller: utrController,
                  decoration: InputDecoration(
                    labelText: 'UPI Reference ID / UTR (Optional)',
                    hintText: 'e.g., 429381048123',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade800,
                    side: BorderSide(color: Colors.blue.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    'I Have Paid ₹$amountStr (Submit Reference ID)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _acceptOrder('UPI', transactionRef: utrController.text.trim());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpiAppChip(String name, String upiUri) {
    return InkWell(
      onTap: () async {
        final ok = await launchUpiIntent(upiUri);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Launched $name. If app did not open, please scan the QR code above or tap 1-Tap Instant Payment.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFF2563EB)),
            const SizedBox(width: 4),
            Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
          ],
        ),
      ),
    );
  }

  void _showCodPaymentSheet(OrderModel order) {
    final amountStr = order.totalAmount.toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cash on Delivery (COD)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Pay cash at your doorstep', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹$amountStr',
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Text('Please keep exact cash of ₹$amountStr ready.', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.electric_moped_rounded, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('Delivery in ~${order.estimatedDeliveryMinutes} minutes to your doorstep.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.security_rounded, size: 16, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Hand over cash to delivery partner, then share your 6-digit delivery OTP code to complete delivery.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.local_shipping_rounded, size: 20),
              label: const Text('Confirm Cash on Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: () {
                Navigator.pop(ctx);
                _acceptOrder('COD');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '📍 Indiranagar, Bengaluru (560038)',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan Handwritten Kirana List',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Take a picture of your paper grocery note. Our AI converts handwriting to items, finds the nearest stores in your area, and lets you pay via Cash on Delivery or UPI!',
                  style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Order Live Tracker (if active order exists)
          if (_activeOrder != null) _buildActiveOrderCard(),

          // Step 1: Camera & Image Upload Card
          _buildUploadSection(),
          const SizedBox(height: 16),

          // Step 2: Extracted Grocery Items & Store Availability
          if (_ocrResult != null) _buildExtractedItemsSection(),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard() {
    final order = _activeOrder!;
    final isPacked = order.status == 'PACKING_CONFIRMED';
    final isOutForDelivery = ['LOOKING_FOR_DELIVERY', 'OUT_FOR_DELIVERY'].contains(order.status);
    final isDelivered = order.status == 'DELIVERED';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF34D399), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.status.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _loadActiveOrder,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF059669)),
                  ),
                ),
                const Spacer(),
                const Text('Est. Delivery: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${order.estimatedDeliveryMinutes} mins',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.orderNumber,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Store: ${order.storeName}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.paymentMode == 'UPI' ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: order.paymentMode == 'UPI' ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.paymentMode == 'UPI' ? Icons.qr_code_rounded : Icons.payments_rounded,
                        size: 13,
                        color: order.paymentMode == 'UPI' ? Colors.blue.shade700 : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.paymentMode == 'UPI'
                            ? (order.paymentStatus == 'COMPLETED' ? 'UPI Paid' : 'UPI')
                            : 'COD (₹${order.totalAmount.toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: order.paymentMode == 'UPI' ? Colors.blue.shade800 : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStepDot('Sent', true),
                _buildStepDot('Packed', order.status != 'PENDING_MERCHANT'),
                _buildStepDot('On Way', isOutForDelivery || isDelivered),
                _buildStepDot('Delivered', isDelivered),
              ],
            ),
            const SizedBox(height: 12),

            // Live Order Journey & Timestamp Tracking
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF0F766E)),
                      SizedBox(width: 6),
                      Text(
                        'Live Order Dates & Timestamps',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  _buildTimelineRow(
                    stepNumber: '1',
                    title: 'Ordered & Sent to Store',
                    timestamp: order.createdAt.isNotEmpty ? order.createdAt : 'Just now',
                    isDone: true,
                    isActive: order.status == 'PENDING_MERCHANT',
                  ),
                  const SizedBox(height: 8),
                  _buildTimelineRow(
                    stepNumber: '2',
                    title: 'Merchant Packed & Billed',
                    timestamp: order.confirmedAt ?? (order.status == 'PENDING_MERCHANT' ? 'Waiting for store...' : 'Packed'),
                    isDone: order.status != 'PENDING_MERCHANT',
                    isActive: order.status == 'PACKING_CONFIRMED',
                  ),
                  const SizedBox(height: 8),
                  _buildTimelineRow(
                    stepNumber: '3',
                    title: 'Handed to Delivery Partner',
                    timestamp: order.dispatchedAt ?? (isOutForDelivery || isDelivered ? 'Dispatched' : 'Awaiting rider...'),
                    isDone: isOutForDelivery || isDelivered,
                    isActive: isOutForDelivery,
                  ),
                  const SizedBox(height: 8),
                  _buildTimelineRow(
                    stepNumber: '4',
                    title: 'Doorstep Delivered',
                    timestamp: order.deliveredAt ?? (isDelivered ? 'Delivered' : 'Expected ~15 mins'),
                    isDone: isDelivered,
                    isActive: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Waiting for merchant to pack
            if (order.status == 'PENDING_MERCHANT') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Store is verifying item availability & preparing confirmed bill...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                          ),
                        ),
                        InkWell(
                          onTap: () => _loadActiveOrder(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF059669)),
                            SizedBox(width: 3),
                            Text(
                              'Auto-syncing every 3s',
                              style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.flash_on_rounded, size: 13),
                          label: const Text(
                            'Instant Confirm (Simulate Store)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            try {
                              await ApiService().quickConfirmOrder(order.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚡ Order confirmed by store! Bill is ready for payment.'),
                                    backgroundColor: Color(0xFF059669),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                              _loadActiveOrder();
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
                    ),
                    if (order.paymentMode == 'UPI' || _checkoutPaymentPreference == 'UPI') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 16),
                        label: const Text('📱 Preview Store UPI QR & VPA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showUpiPaymentSheet(order),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Step 9: Confirmation Request from Merchant
            if (isPacked)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Merchant Packed Your Bill!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF78350F)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Itemized Stock Confirmation List
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Store Availability & Pricing Checklist:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 6),
                          ...order.items.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  it.isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 14,
                                  color: it.isAvailable ? const Color(0xFF059669) : Colors.redAccent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    it.productName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      decoration: it.isAvailable ? null : TextDecoration.lineThrough,
                                      color: it.isAvailable ? Colors.black87 : Colors.grey,
                                    ),
                                  ),
                                ),
                                Text(
                                  it.isAvailable
                                      ? '${it.packedQuantity > 0 ? it.packedQuantity : it.requestedQuantity} ${it.unit} • ₹${((it.packedQuantity > 0 ? it.packedQuantity : it.requestedQuantity) * it.unitPrice).toStringAsFixed(2)}'
                                      : 'Out of stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: it.isAvailable ? FontWeight.bold : FontWeight.normal,
                                    color: it.isAvailable ? const Color(0xFF059669) : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          const Divider(height: 14, color: Color(0xFFFDE68A)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Items Subtotal:', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                              Text('₹${order.itemsSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee (₹50/km):', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                              Text(
                                '₹${order.deliveryFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12, color: Color(0xFFFDE68A)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Bill:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF451A03))),
                              Text('₹${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF451A03))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Choose payment method to trigger immediate delivery dispatch:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF451A03)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.payments_rounded, size: 16),
                            onPressed: () => _showCodPaymentSheet(order),
                            label: const Text('Pay COD', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code_rounded, size: 16),
                            onPressed: () => _showUpiPaymentSheet(order),
                            label: const Text('Pay UPI / QR', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (order.paymentMode == 'UPI' || _checkoutPaymentPreference == 'UPI') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 16),
                        label: const Text('📱 Preview Store UPI QR & VPA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showUpiPaymentSheet(order),
                      ),
                    ],
                  ],
                ),
              ),

            // 6-Digit Delivery OTP Code Display
            if (isOutForDelivery) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR 6-DIGIT DELIVERY CODE',
                      style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveryCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '🔒 Share this code with the delivery partner upon arrival to complete delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Delivery Partner Info
            if (order.deliveryPartnerName != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.delivery_dining_rounded, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.deliveryPartnerName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(order.deliveryPartnerVehicle ?? 'Rider', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Order Delivered Success Banner & Loop
            if (isDelivered) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Order Delivered Successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Thank you for shopping local with Smart Cart AI.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: const Text('Start New Order / Scan Another Note'),
                        onPressed: () {
                          setState(() => _activeOrder = null);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepDot(String title, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? const Color(0xFF059669) : Colors.grey.shade300,
          child: Text(
            active ? '✓' : '•',
            style: TextStyle(color: active ? Colors.white : Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildTimelineRow({
    required String stepNumber,
    required String title,
    required String timestamp,
    required bool isDone,
    required bool isActive,
  }) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF059669) : (isActive ? const Color(0xFF2563EB) : Colors.grey.shade200),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : Text(
                  stepNumber,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade600),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isDone || isActive) ? FontWeight.bold : FontWeight.normal,
              color: (isDone || isActive) ? const Color(0xFF0F172A) : Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          timestamp,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            color: isDone ? const Color(0xFF059669) : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload / Scan Handwritten List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Take a photo of your paper list, pick a saved image, or type items directly:', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Live Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _openLiveCamera,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Saved Photo', style: TextStyle(fontSize: 12)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFF059669),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Type List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _showManualTextDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample Presets
            const Text('OR USE 1-CLICK SAMPLE HANDWRITTEN LISTS:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF059669)),
                  label: const Text('Weekly Ration (8 items)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _usePreset('weekly_ration'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.breakfast_dining_rounded, size: 14, color: Colors.amber),
                  label: const Text('Daily Essentials (6 items)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _usePreset('breakfast'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.cleaning_services_rounded, size: 14, color: Colors.blue),
                  label: const Text('Home Cleaning (6 items)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _usePreset('home_care'),
                ),
              ],
            ),

            if (_isProcessingOcr) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                    SizedBox(height: 8),
                    Text('Running Computer Vision & Kirana NLP...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],

            // OpenCV Annotated Preview
            if (_ocrResult != null && _ocrResult!.annotatedImageBase64 != null) ...[
              const SizedBox(height: 14),
              const Text('OpenCV AI Detection Bounding Boxes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  base64Decode(_ocrResult!.annotatedImageBase64!.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedItemsSection() {
    final items = _ocrResult!.items;

    if (items.isEmpty) {
      final raw = _ocrResult?.rawText.trim() ?? '';
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
        ),
        color: const Color(0xFFFFFBEB),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 36),
              const SizedBox(height: 10),
              Text(
                raw.isNotEmpty ? 'Could Not Match Recognized Words to Groceries' : 'No handwriting detected in this capture',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
              ),
              const SizedBox(height: 6),
              Text(
                raw.isNotEmpty
                    ? 'AI read: "$raw". Tap "Edit Scanned Text" to adjust spelling or enter your items directly:'
                    : 'Please hold the paper steady with good lighting, or tap below to enter your items directly:',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(raw.isNotEmpty ? 'Edit Scanned Text ($raw)' : 'Enter Grocery List Manually'),
                onPressed: () => _showManualTextDialog(raw.isNotEmpty ? raw : null),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Scanned Grocery Items Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                      child: const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scanned Grocery Items (${items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const Text('Adjust quantities or tap item to edit name/unit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        foregroundColor: const Color(0xFF059669),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF34D399)),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _showAddItemDialog,
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Interactive items list with quantity steppers and quick edit
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final it = items[idx];
                    return InkWell(
                      onTap: () => _showEditItemDialog(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('${idx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12)),
                                      Expanded(
                                        child: Text(
                                          it.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${it.brand} • ${it.category}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Quantity Stepper [-] QTY [+]
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _updateItemQuantity(idx, -1.0),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: Icon(Icons.remove, size: 14, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '${it.quantity % 1 == 0 ? it.quantity.toInt() : it.quantity} ${it.unit}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _updateItemQuantity(idx, 1.0),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: Icon(Icons.add, size: 14, color: Color(0xFF059669)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() => items.removeAt(idx));
                                _checkAvailability();
                                _compareStores();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Raw OCR Inspection & Edit Card (Solves Issue 9: full transparency of extracted text)
        if (_ocrResult != null && _ocrResult!.rawText.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: const Icon(Icons.document_scanner_rounded, size: 20, color: Color(0xFF0F766E)),
                title: const Text(
                  '📝 View / Edit Raw OCR Text',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
                subtitle: const Text(
                  'Tap to inspect what AI read from your paper list',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            _ocrResult!.rawText,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Edit Text & Re-parse List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showManualTextDialog(_ocrResult!.rawText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 2. Nearest Kirana Stores to Your Area Section
        _buildNearestStoresComparisonSection(),
        const SizedBox(height: 16),

        // 3. Selected Store Inventory Breakdown & Checkout Card
        _buildCheckoutSummaryCard(),
      ],
    );
  }

  Widget _buildNearestStoresComparisonSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF34D399), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearest Kirana Stores to Your Area', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Compare stock availability & total bill across shops', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_isComparingStores)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_storeComparisons.isNotEmpty) ...[
              // Comparison list of cards
              ..._storeComparisons.map((comp) {
                final st = comp['store'];
                final storeId = st['id'] as int;
                final isSelected = _selectedStore != null && _selectedStore!.id == storeId;
                final is100Percent = comp['all_items_available'] == true;
                final totalItems = comp['total_items_requested'] ?? 0;
                final availItems = comp['available_count'] ?? 0;
                final bill = comp['total_bill'] ?? 0.0;
                final dist = (st['distance_km'] is num) ? (st['distance_km'] as num).toDouble() : 0.5;
                final deliveryMins = st['estimated_delivery_minutes'] ?? 15;
                final compDeliveryFee = (comp['delivery_fee'] is num)
                    ? (comp['delivery_fee'] as num).toDouble()
                    : (dist * 50.0);

                return InkWell(
                  onTap: () {
                    final match = _stores.firstWhere((s) => s.id == storeId, orElse: () => _selectedStore!);
                    _selectStoreAndRecalculate(match);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF059669) : Colors.grey.shade300,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(st['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: 10, color: Colors.amber),
                                            const SizedBox(width: 2),
                                            Text('${st['rating']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '📍 ${dist} km away • ${st['address']}',
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF059669) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isSelected ? '✓ Selected' : 'Select',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: is100Percent ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    is100Percent ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    size: 12,
                                    color: is100Percent ? const Color(0xFF047857) : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    is100Percent ? '$availItems of $totalItems in Stock (100%)' : '$availItems of $totalItems in Stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: is100Percent ? const Color(0xFF047857) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text('⚡ ${deliveryMins}m delivery', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    '+₹${compDeliveryFee.toStringAsFixed(0)} Delv (${dist.toStringAsFixed(1)}km)',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹$bill',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ] else ...[
              // Fallback Dropdown if comparisons still loading
              DropdownButtonFormField<StoreModel>(
                value: _selectedStore,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _stores.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (⭐ ${s.rating})', style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) {
                  if (val != null) _selectStoreAndRecalculate(val);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSummaryCard() {
    final storeName = _selectedStore?.name ?? 'Selected Kirana Store';
    final storeDistance = _selectedStore?.distanceKm ?? (_availabilityData?['distance_km'] as num?)?.toDouble() ?? 1.0;
    final totalBill = (_availabilityData?['total_bill'] is num) ? (_availabilityData!['total_bill'] as num).toDouble() : 0.0;
    final itemsSubtotal = (_availabilityData?['items_subtotal'] is num) ? (_availabilityData!['items_subtotal'] as num).toDouble() : totalBill;
    final deliveryFee = (_availabilityData?['delivery_fee'] is num)
        ? (_availabilityData!['delivery_fee'] as num).toDouble()
        : (storeDistance * 50.0);
    final availableCount = _availabilityData?['available_count'] ?? _ocrResult?.items.length ?? 0;
    final totalItems = _availabilityData?['total_items_requested'] ?? _ocrResult?.items.length ?? 0;
    final missingCount = _availabilityData?['missing_count'] ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_rounded, size: 20, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order Bill at $storeName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '₹${totalBill.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF059669)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$availableCount of $totalItems items in stock', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  Text('Distance: ${storeDistance.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // 🚚 Delivery Fee Policy Banner: ₹50 / km (Free delivery NOT available)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    size: 16,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🚚 Delivery Fee: ₹50 per km (${storeDistance.toStringAsFixed(1)} km • ₹${deliveryFee.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Detailed Itemized Price Breakdown
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items Subtotal:', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      Text('₹${itemsSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delivery Fee (${storeDistance.toStringAsFixed(1)} km @ ₹50/km):', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      Text(
                        '₹${deliveryFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('₹${totalBill.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                    ],
                  ),
                ],
              ),
            ),

            if (missingCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$missingCount item(s) out of stock here. You can select another store above with 1 tap.',
                        style: TextStyle(fontSize: 10, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Payment Mode Selector (COD vs UPI)
            const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _checkoutPaymentPreference = 'COD'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _checkoutPaymentPreference == 'COD' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _checkoutPaymentPreference == 'COD' ? const Color(0xFF059669) : Colors.grey.shade300,
                          width: _checkoutPaymentPreference == 'COD' ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_rounded, size: 18, color: _checkoutPaymentPreference == 'COD' ? const Color(0xFF059669) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _checkoutPaymentPreference == 'COD' ? const Color(0xFF065F46) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _checkoutPaymentPreference = 'UPI'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _checkoutPaymentPreference == 'UPI' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _checkoutPaymentPreference == 'UPI' ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: _checkoutPaymentPreference == 'UPI' ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_rounded, size: 18, color: _checkoutPaymentPreference == 'UPI' ? Colors.blue.shade700 : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'UPI / QR Pay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _checkoutPaymentPreference == 'UPI' ? Colors.blue.shade900 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _checkoutPaymentPreference == 'COD'
                  ? '💵 Pay cash to rider upon doorstep delivery. Keep ₹$totalBill ready.'
                  : '📱 Pay instantly via QR code or direct UPI app (GPay, PhonePe, Paytm, BHIM).',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                'Send List to $storeName for Packing',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _submitOrderToMerchant,
            ),
          ],
        ),
      ),
    );
  }
}

