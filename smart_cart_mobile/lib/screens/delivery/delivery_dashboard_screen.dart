import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/order_model.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  OrderModel? _activeOrder;
  List<Map<String, dynamic>> _availableGigs = [];
  bool _isOnline = true;
  Timer? _pollTimer;
  int _previousGigCount = -1;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      _loadDeliveries();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    final user = ApiService().currentUser;
    if (user == null) return;
    try {
      final res = await ApiService().fetchDeliveryGigs(user.id);
      setState(() {
        if (res['active_order'] != null) {
          _activeOrder = OrderModel.fromJson(res['active_order']);
        } else {
          _activeOrder = null;
        }
        var gigs = res['available_gigs'] as List? ?? [];
        _availableGigs = gigs.cast<Map<String, dynamic>>();

        // Trigger active notification when a new gig arrives
        if (_previousGigCount != -1 && _availableGigs.length > _previousGigCount) {
          final newGig = _availableGigs.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔔 New Order Ready for Pickup at ${newGig['store_name']} (Earn ₹${newGig['delivery_fee']})!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _previousGigCount = _availableGigs.length;
      });
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    }
  }

  Future<void> _acceptGig(int orderId) async {
    final user = ApiService().currentUser;
    if (user == null) return;
    try {
      await ApiService().acceptDeliveryGig(user.id, orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery Gig accepted! Proceed to pickup store.'), backgroundColor: Color(0xFF059669)),
      );
      _loadDeliveries();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept gig: $e')),
      );
    }
  }

  void _showVerifyCodeDialog() {
    if (_activeOrder == null) return;
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Verify Delivery Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask the customer for their 6-digit delivery code upon arrival:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '482910',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final user = ApiService().currentUser;
              if (user == null) return;

              final code = codeController.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit code')),
                );
                return;
              }

              try {
                final res = await ApiService().verifyDeliveryCode(user.id, _activeOrder!.id, code);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Delivery verified and completed!'), backgroundColor: const Color(0xFF059669)),
                  );
                }
                _loadDeliveries();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryStatChip(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
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
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.name ?? 'Delivery Partner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${user?.vehicleType ?? "Bike"} • ${user?.vehicleNumber ?? "KA-04"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          Row(
            children: [
              Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 11, color: _isOnline ? const Color(0xFF059669) : Colors.grey, fontWeight: FontWeight.bold)),
              Switch(
                value: _isOnline,
                activeColor: const Color(0xFF059669),
                onChanged: (v) => setState(() => _isOnline = v),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliveries,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Delivery Rider Operations Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.35),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: _isOnline ? const Color(0xFF34D399) : Colors.grey.shade400),
                            const SizedBox(width: 5),
                            Text(_isOnline ? 'ONLINE & READY FOR GIGS' : 'OFFLINE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text('4.9 Rating', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Delivery Partner',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user?.vehicleType ?? "Bike"} • ${user?.vehicleNumber ?? "KA-04-EK-9821"} • Indiranagar Hub',
                    style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildDeliveryStatChip('Available Gigs', '${_availableGigs.length}', Icons.work_outline_rounded),
                      const SizedBox(width: 8),
                      _buildDeliveryStatChip('Completed', '12', Icons.task_alt_rounded),
                      const SizedBox(width: 8),
                      _buildDeliveryStatChip('Today Earned', '₹540.00', Icons.currency_rupee_rounded),
                    ],
                  ),
                ],
              ),
            ),
            // Active Delivery in Progress (If assigned)
            if (_activeOrder != null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFF059669), width: 2),
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
                            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                            child: const Text('ACTIVE DELIVERY', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                          const Spacer(),
                          const Text('+₹45.00 Payout', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_activeOrder!.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),

                      // Route Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('1. STORE PICKUP: ${_activeOrder!.storeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(_activeOrder!.storeAddress, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const Divider(height: 16),
                            Text('2. CUSTOMER DROP:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(_activeOrder!.deliveryAddress, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Order Progression Timestamps
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF0F766E)),
                                SizedBox(width: 6),
                                Text('Live Order Progression Timestamps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTimestampRow(Icons.shopping_bag_outlined, '1. Customer Ordered:', _activeOrder!.createdAt),
                            const SizedBox(height: 5),
                            _buildTimestampRow(Icons.inventory_2_outlined, '2. Store Packed & Ready:', _activeOrder!.confirmedAt ?? 'Pending Store packing'),
                            const SizedBox(height: 5),
                            _buildTimestampRow(Icons.two_wheeler_rounded, '3. Picked by You:', _activeOrder!.dispatchedAt ?? 'In Progress'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment Collection Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFFFCD34D) : const Color(0xFF93C5FD),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _activeOrder!.paymentMode == 'COD' ? Icons.payments_rounded : Icons.check_circle_rounded,
                                color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFFD97706) : Colors.blue.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activeOrder!.paymentMode == 'COD'
                                        ? '💵 COLLECT CASH: ₹${_activeOrder!.totalAmount.toStringAsFixed(2)}'
                                        : '✅ ONLINE PAID VIA UPI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFF92400E) : Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeOrder!.paymentMode == 'COD'
                                        ? 'Collect exact cash from customer before OTP verification'
                                        : 'Customer paid ₹${_activeOrder!.totalAmount.toStringAsFixed(2)} online. DO NOT collect cash!',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _activeOrder!.paymentMode == 'COD' ? const Color(0xFF78350F) : Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // CRITICAL STEP 11-15: Verify 6-digit Code Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('Verify 6-Digit Delivery Code', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showVerifyCodeDialog,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Available Gigs List
            const Text('Available Delivery Gigs in Indiranagar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (_availableGigs.isEmpty && _activeOrder == null)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                child: const Text('No delivery gigs available right now. When customers place orders, gigs appear here!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ..._availableGigs.map((g) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(g['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                            child: Text('+₹${g['delivery_fee']} Fee', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Pickup: ${g['store_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      Text('Drop: ${g['customer_address']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (g['created_at'] != null || g['confirmed_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Ordered: ${g['created_at'] ?? 'N/A'}${g['confirmed_at'] != null ? ' • Packed: ${g['confirmed_at']}' : ''}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: g['payment_mode'] == 'COD' ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: g['payment_mode'] == 'COD' ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  g['payment_mode'] == 'COD' ? Icons.payments_rounded : Icons.qr_code_rounded,
                                  size: 12,
                                  color: g['payment_mode'] == 'COD' ? const Color(0xFFB45309) : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  g['payment_mode'] == 'COD' ? '💵 COD: Collect ₹${g['total_amount']}' : '📱 UPI Paid (Online)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: g['payment_mode'] == 'COD' ? const Color(0xFF92400E) : Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _acceptGig(g['id']),
                        child: const Text('Accept Delivery Gig'),
                      ),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
