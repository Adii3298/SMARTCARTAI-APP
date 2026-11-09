import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Function(String targetRole)? onSuperviseRole;

  const AdminDashboardScreen({Key? key, this.onSuperviseRole}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _deliveryPartners = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().fetchAdminAnalytics();
      final logs = await ApiService().fetchAdminActivityLogs();
      final orders = await ApiService().fetchAdminOrders();
      final custs = await ApiService().fetchAdminUsers(role: 'customer');
      final mercs = await ApiService().fetchAdminUsers(role: 'merchant');
      final delvs = await ApiService().fetchAdminUsers(role: 'delivery');

      setState(() {
        _analytics = res['analytics'];
        _logs = logs;
        _allOrders = orders;
        _customers = custs;
        _merchants = mercs;
        _deliveryPartners = delvs;
      });
    } catch (e) {
      debugPrint('Admin load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUser(int userId, String userName) async {
    try {
      final success = await ApiService().toggleUserStatus(userId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated for $userName'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Header
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF6B21A8),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF6B21A8),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Customers'),
              Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Merchants'),
              Tab(icon: Icon(Icons.delivery_dining_rounded, size: 18), text: 'Delivery'),
              Tab(icon: Icon(Icons.supervised_user_circle_rounded, size: 18), text: 'Supervise Portals'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildCustomersTab(),
                _buildMerchantsTab(),
                _buildDeliveryTab(),
                _buildSuperviseTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================
  // TAB 1: OVERVIEW & ANALYTICS
  // ========================================================
  Widget _buildOverviewTab() {
    if (_isLoading && _analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B21A8).withOpacity(0.3),
                blurRadius: 16,
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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('⚡ Platform Administrator', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              const Text('Smart Cart AI Control Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Unified governance across Shoppers, Kirana Merchants & Delivery Partners', style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_analytics != null) ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard('Total GMV Revenue', '₹${_analytics!['total_gmv']}', Icons.currency_rupee_rounded, Colors.green),
              _buildMetricCard('Total Orders', '${_analytics!['total_orders']}', Icons.receipt_long_rounded, Colors.blue),
              _buildMetricCard('Kirana Stores', '${_analytics!['stores_count']}', Icons.storefront_rounded, Colors.amber),
              _buildMetricCard('Delivery Partners', '${_analytics!['delivery_count']}', Icons.delivery_dining_rounded, Colors.teal),
              _buildMetricCard('Shopper Accounts', '${_analytics!['customers_count']}', Icons.people_alt_rounded, Colors.indigo),
              _buildMetricCard('Smart Cart Nodes', '${_analytics!['nodes_count']}', Icons.hub_rounded, Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // Live Platform Orders & Lifecycle Timestamps
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF6B21A8)),
                      const SizedBox(width: 8),
                      const Text('Live Orders Lifecycle Dates & Timestamps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(10)),
                        child: Text('${_allOrders.length} Orders', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_allOrders.isEmpty)
                    const Text('No orders placed on the platform yet.', style: TextStyle(color: Colors.grey, fontSize: 11))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allOrders.length > 5 ? 5 : _allOrders.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (ctx, idx) {
                        final ord = _allOrders[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(ord['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusBg(ord['status']),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (ord['status'] ?? '').replaceAll('_', ' '),
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getStatusColor(ord['status'])),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('₹${ord['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '👤 Customer: ${ord['customer_name']} • 🏪 Store: ${ord['store_name']} • 🛵 Rider: ${ord['delivery_name']}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    _buildAdminTimelineRow(Icons.shopping_bag_outlined, '1. Ordered (Requested to Merchant)', ord['created_at'], true),
                                    const SizedBox(height: 4),
                                    _buildAdminTimelineRow(Icons.inventory_2_outlined, '2. Packed by Kirana Store', ord['confirmed_at'], ord['confirmed_at'] != null),
                                    const SizedBox(height: 4),
                                    _buildAdminTimelineRow(Icons.two_wheeler_rounded, '3. Dispatched to Delivery Partner', ord['dispatched_at'], ord['dispatched_at'] != null),
                                    const SizedBox(height: 4),
                                    _buildAdminTimelineRow(Icons.task_alt_rounded, '4. Delivered to Doorstep (OTP)', ord['delivered_at'], ord['delivered_at'] != null),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Audit logs
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFF6B21A8)),
                      SizedBox(width: 8),
                      Text('Live Platform Audit Trail & System Logs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_logs.isEmpty)
                    const Text('No activity logs recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 11))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length > 8 ? 8 : _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final log = _logs[idx];
                        final role = (log['role'] ?? 'system').toString().toLowerCase();

                        Color tagColor = Colors.grey;
                        if (role == 'customer') tagColor = const Color(0xFF059669);
                        if (role == 'merchant') tagColor = Colors.amber.shade800;
                        if (role == 'delivery') tagColor = Colors.teal;
                        if (role == 'admin') tagColor = Colors.purple;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tagColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(role.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tagColor)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log['details'] ?? log['action'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(log['time'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ========================================================
  // TAB 2: CUSTOMERS DIRECTORY
  // ========================================================
  Widget _buildCustomersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 8),
            Text('Registered Shoppers (${_customers.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Review customer accounts, total orders placed, and manage active status.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),

        if (_customers.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No customers registered yet.')))
        else
          ..._customers.map((c) {
            final isActive = c['is_active'] == true;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFD1FAE5),
                      child: Text(
                        (c['name'] ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFD1FAE5) : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Disabled',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF047857) : Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('ID: ${c['user_id']} • 📞 +91-${c['mobile']}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          Text('📍 ${c['area'] ?? ''} (${c['pincode'] ?? ''}) • Orders: ${c['orders_count'] ?? 0}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: const Color(0xFF059669),
                      onChanged: (val) => _toggleUser(c['id'], c['name'] ?? 'Customer'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // ========================================================
  // TAB 3: MERCHANTS DIRECTORY
  // ========================================================
  Widget _buildMerchantsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 8),
            Text('Kirana Store Merchants (${_merchants.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Review store profiles, inventory product sizes, and manage store operational status.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),

        if (_merchants.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No merchants registered yet.')))
        else
          ..._merchants.map((m) {
            final isActive = m['is_active'] == true;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['store_name'] ?? m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Owner: ${m['name']} • ID: ${m['user_id']}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          activeColor: const Color(0xFFD97706),
                          onChanged: (val) => _toggleUser(m['id'], m['name'] ?? 'Merchant'),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📍 ${m['area'] ?? ''} (${m['pincode'] ?? ''})', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: Text('${m['total_products'] ?? 0} Catalog Products', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                    if (m['upi_id'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('UPI: ${m['upi_id']}', style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // ========================================================
  // TAB 4: DELIVERY FLEET
  // ========================================================
  Widget _buildDeliveryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.delivery_dining_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 8),
            Text('Delivery Partners (${_deliveryPartners.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Manage vehicle types, license plates, completed drops, and active duty status.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),

        if (_deliveryPartners.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No delivery partners registered yet.')))
        else
          ..._deliveryPartners.map((d) {
            final isActive = d['is_active'] == true;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(d['vehicle_type'] ?? 'Bike', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('ID: ${d['user_id']} • Plate: ${d['vehicle_number'] ?? 'KA-04-XX-0000'}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          Text('📞 +91-${d['mobile']} • Drops Completed: ${d['orders_count'] ?? 0}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (val) => _toggleUser(d['id'], d['name'] ?? 'Rider'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // ========================================================
  // TAB 5: SUPERVISE & INSPECT PORTALS (ADMIN EXCLUSIVE)
  // ========================================================
  Widget _buildSuperviseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C3AED), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Exclusive Admin Supervision Authority',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF581C87)),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Only the platform administrator has permission to inspect and work on other portals. '
                'Regular customers, merchants, and delivery partners are strictly locked into their own portals.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'SELECT PORTAL TO INSPECT & WORK ON:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        // 1. Inspect Customer Portal
        _buildSuperviseCard(
          title: 'Inspect Customer Experience Portal',
          subtitle: 'Test live handwritten list OCR scanning, nearest Kirana store stock match, bill calculation, and Cash on Delivery or UPI checkout.',
          role: 'customer',
          color: const Color(0xFF059669),
          icon: Icons.shopping_basket_rounded,
        ),
        const SizedBox(height: 12),

        // 2. Inspect Merchant Portal
        _buildSuperviseCard(
          title: 'Inspect Kirana Merchant Portal',
          subtitle: 'Review live incoming customer orders, perform item packing, confirm packed bills, and manage inventory items.',
          role: 'merchant',
          color: const Color(0xFFD97706),
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: 12),

        // 3. Inspect Delivery Partner Portal
        _buildSuperviseCard(
          title: 'Inspect Delivery Portal',
          subtitle: 'Inspect available delivery pickup gigs, accept orders, collect Cash on Delivery, and verify doorstep 6-digit delivery OTP codes.',
          role: 'delivery',
          color: const Color(0xFF2563EB),
          icon: Icons.delivery_dining_rounded,
        ),
      ],
    );
  }

  Widget _buildSuperviseCard({
    required String title,
    required String subtitle,
    required String role,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Open ${role.toUpperCase()} Portal in Supervision Mode', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              onPressed: () {
                widget.onSuperviseRole?.call(role);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTimelineRow(IconData icon, String label, String? timestamp, bool isDone) {
    return Row(
      children: [
        Icon(icon, size: 12, color: isDone ? const Color(0xFF059669) : Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            color: isDone ? const Color(0xFF1E293B) : Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Text(
          timestamp ?? 'Pending',
          style: TextStyle(
            fontSize: 9,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            color: isDone ? const Color(0xFF059669) : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Color _getStatusBg(String? status) {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFFD1FAE5);
      case 'OUT_FOR_DELIVERY':
        return const Color(0xFFDBEAFE);
      case 'LOOKING_FOR_DELIVERY':
        return const Color(0xFFE0E7FF);
      case 'PACKING_CONFIRMED':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF047857);
      case 'OUT_FOR_DELIVERY':
        return const Color(0xFF1D4ED8);
      case 'LOOKING_FOR_DELIVERY':
        return const Color(0xFF4338CA);
      case 'PACKING_CONFIRMED':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF475569);
    }
  }
}
