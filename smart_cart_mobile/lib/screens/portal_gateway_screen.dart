import 'package:flutter/material.dart';
import '../../services/navigation/url_launcher_service.dart';
import '../widgets/server_config_dialog.dart';

class PortalGatewayScreen extends StatelessWidget {
  final Function(String portalRole) onSelectPortal;
  final Function(String portalRole)? onInstantLaunch;

  const PortalGatewayScreen({
    Key? key,
    required this.onSelectPortal,
    this.onInstantLaunch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.8),
            radius: 1.2,
            colors: [
              Color(0xFF0D2520),
              Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Brand Bar with Settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Smart Cart AI',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF10B981),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'LIVE CLOUD DEPLOYMENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8), size: 22),
                      tooltip: 'Server Settings & Configuration',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B).withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => ServerConfigDialog.show(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Hero Headline Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF131D30), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF34D399)),
                            SizedBox(width: 6),
                            Text(
                              'AI-POWERED HYPERLOCAL PLATFORM',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Next-Gen Kirana Network',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Digitize handwritten grocery notes with Computer Vision, compare local store stocks in real-time, and dispatch orders with secure 6-digit OTPs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4 Key Capability Metric Badges
                      Row(
                        children: [
                          _buildMetricPill(
                            icon: Icons.bolt_rounded,
                            title: '< 1.2s',
                            subtitle: 'AI OCR',
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          _buildMetricPill(
                            icon: Icons.store_rounded,
                            title: '2 Stores',
                            subtitle: 'Kirana Stock',
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          _buildMetricPill(
                            icon: Icons.pin_rounded,
                            title: '6-Digit',
                            subtitle: 'OTP Delivery',
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          _buildMetricPill(
                            icon: Icons.security_rounded,
                            title: '4 Roles',
                            subtitle: 'Strict Auth',
                            color: const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Launch Bar
                const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Color(0xFF34D399), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'DIRECT PORTAL LAUNCH',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickPill(
                        label: 'Customer',
                        icon: Icons.shopping_basket_rounded,
                        color: const Color(0xFF059669),
                        onTap: () => onSelectPortal('customer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickPill(
                        label: 'Kirana Store',
                        icon: Icons.storefront_rounded,
                        color: const Color(0xFFD97706),
                        onTap: () => onSelectPortal('merchant'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickPill(
                        label: 'Delivery',
                        icon: Icons.delivery_dining_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => onSelectPortal('delivery'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickPill(
                        label: 'Admin',
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => onSelectPortal('admin'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 1. CUSTOMER PORTAL CARD
                _buildPortalCard(
                  title: 'Customer Grocery App',
                  badge: 'CONSUMER ORDERING',
                  badgeColor: const Color(0xFF10B981),
                  accentColor: const Color(0xFF059669),
                  icon: Icons.shopping_basket_rounded,
                  description: 'Scan handwritten grocery lists using RapidOCR, compare item-by-item prices between Navjeevan Supermart and More Provision, pay via UPI/COD, and track live deliveries.',
                  features: const ['📷 Live Camera & Upload OCR', '⚖️ Multi-Store Comparison', '💳 GPay/PhonePe UPI QR', '📍 Live OTP Tracking'],
                  actionText: 'Enter Customer Portal',
                  onTap: () => onSelectPortal('customer'),
                  isPrimary: true,
                ),
                const SizedBox(height: 16),

                // 2. MERCHANT PORTAL CARD
                _buildPortalCard(
                  title: 'Kirana Merchant Partner',
                  badge: 'STORE PARTNERS ONLY',
                  badgeColor: const Color(0xFFF59E0B),
                  accentColor: const Color(0xFFD97706),
                  icon: Icons.storefront_rounded,
                  description: 'Dedicated interface for Navjeevan Supermart & More Provision store owners. View incoming orders, confirm packed quantities, update stock prices, and track revenue.',
                  features: const ['📦 Real-Time Order Queue', '✅ Pack & Confirm Workflow', '📊 80+ Item Inventory Control', '💰 Daily GMV Dashboard'],
                  actionText: 'Enter Merchant Portal',
                  onTap: () => onSelectPortal('merchant'),
                ),
                const SizedBox(height: 16),

                // 3. DELIVERY PORTAL CARD
                _buildPortalCard(
                  title: 'Delivery Rider Portal',
                  badge: 'DELIVERY FLEET',
                  badgeColor: const Color(0xFF3B82F6),
                  accentColor: const Color(0xFF2563EB),
                  icon: Icons.delivery_dining_rounded,
                  description: 'For delivery riders to accept store pickup gigs, view turn-by-turn customer delivery directions, collect cash on delivery, and complete handovers via 6-digit OTP.',
                  features: const ['🛵 Live Gig Dispatch', '📍 Store & Customer Address', '🔢 6-Digit Drop-off OTP', '💵 COD Cash Reconciliation'],
                  actionText: 'Enter Delivery Portal',
                  onTap: () => onSelectPortal('delivery'),
                ),
                const SizedBox(height: 16),

                // 4. ADMIN PORTAL CARD
                _buildPortalCard(
                  title: 'Admin Command Center',
                  badge: 'SYSTEM ADMINISTRATOR',
                  badgeColor: const Color(0xFF8B5CF6),
                  accentColor: const Color(0xFF7C3AED),
                  icon: Icons.admin_panel_settings_rounded,
                  description: 'Comprehensive administrative oversight across all nodes, Kirana stores, riders, and customers. Includes supervisory portal inspection mode and platform health metrics.',
                  features: const ['👑 Platform-wide GMV & Orders', '🔍 Multi-Portal Inspection', '🏢 Smart Cart Nodes Map', '👥 User Status Control'],
                  actionText: 'Enter Admin Center',
                  onTap: () => onSelectPortal('admin'),
                ),
                const SizedBox(height: 22),

                // Android Standalone APK Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F231C), Color(0xFF0A1813)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.android_rounded, color: Color(0xFF34D399), size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Install Standalone Android App',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Native Android APK with high-speed camera scanning & zero latency.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: const Color(0xFF090D16),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: const Text(
                            'Download SmartCart-Release.apk (53.7 MB)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          onPressed: () {
                            openExternalUrl('/static/SmartCart-Release.apk');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Footer
                const Center(
                  child: Text(
                    'Smart Cart AI • Hyperlocal Kirana Delivery Network',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required Color accentColor,
    required IconData icon,
    required String description,
    required List<String> features,
    required String actionText,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPrimary ? badgeColor.withOpacity(0.8) : const Color(0xFF1F2937),
          width: isPrimary ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary ? badgeColor.withOpacity(0.2) : Colors.black.withOpacity(0.3),
            blurRadius: isPrimary ? 20 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, badgeColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),

                // Features Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: features.map((feat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155).withOpacity(0.6)),
                      ),
                      child: Text(
                        feat,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      actionText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
