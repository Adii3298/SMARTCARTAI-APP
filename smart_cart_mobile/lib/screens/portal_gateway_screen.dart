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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Brand & Server Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Balances the gear icon on the right
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Cart AI',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.android, size: 13, color: Color(0xFF3DDC84)),
                              SizedBox(width: 4),
                              Text(
                                'Android Only Edition',
                                style: TextStyle(fontSize: 12, color: Color(0xFF3DDC84), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_ethernet_rounded, color: Color(0xFF94A3B8), size: 22),
                    tooltip: 'Backend Server Settings',
                    onPressed: () => ServerConfigDialog.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Welcome Banner & Strict Isolation Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3DDC84).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.android, size: 13, color: Color(0xFF3DDC84)),
                              SizedBox(width: 5),
                              Text(
                                'ANDROID EXCLUSIVE',
                                style: TextStyle(
                                  color: Color(0xFF3DDC84),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF059669).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF34D399)),
                              SizedBox(width: 5),
                              Text(
                                'ROLE ISOLATED',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Your Designated Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dedicated Android application for shoppers, Navjeevan, More Provision, and delivery riders. Portals are strictly separated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Direct Portal Access
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: Color(0xFF34D399), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'DIRECT PORTAL SELECTION',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select your designated portal below to open its dedicated Sign In & authentication screen:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickButton(
                            label: 'Customer App',
                            icon: Icons.shopping_basket_rounded,
                            color: const Color(0xFF059669),
                            role: 'customer',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickButton(
                            label: 'Kirana Store',
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFFD97706),
                            role: 'merchant',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickButton(
                            label: 'Delivery Rider',
                            icon: Icons.delivery_dining_rounded,
                            color: const Color(0xFF2563EB),
                            role: 'delivery',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickButton(
                            label: 'Admin Control',
                            icon: Icons.admin_panel_settings_rounded,
                            color: const Color(0xFF7C3AED),
                            role: 'admin',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. CUSTOMER PORTAL CARD (Highlighted Primary)
              _buildPortalCard(
                title: 'Customer Grocery App',
                badge: 'CONSUMER APP',
                badgeColor: const Color(0xFF059669),
                gradient: const [Color(0xFF065F46), Color(0xFF047857)],
                icon: Icons.shopping_basket_rounded,
                description: 'Scan handwritten grocery lists with AI OCR, order from Navjeevan & More Provision, pay with UPI or Cash on Delivery (COD) & track deliveries.',
                actionText: 'Sign In / Register',
                onTap: () => onSelectPortal('customer'),
                isPrimary: true,
              ),
              const SizedBox(height: 14),

              // 2. MERCHANT PORTAL CARD
              _buildPortalCard(
                title: 'Kirana Merchant Portal',
                badge: 'STORE PARTNERS ONLY',
                badgeColor: const Color(0xFFD97706),
                gradient: const [Color(0xFF78350F), Color(0xFF92400E)],
                icon: Icons.storefront_rounded,
                description: 'Manage grocery orders, confirm packed quantities, update item prices, and track live inventory for both local stores (Navjeevan Supermart & More Provision).',
                actionText: 'Sign In / Register',
                onTap: () => onSelectPortal('merchant'),
              ),
              const SizedBox(height: 14),

              // 3. DELIVERY PORTAL CARD
              _buildPortalCard(
                title: 'Delivery Portal',
                badge: 'RIDERS & DRIVERS ONLY',
                badgeColor: const Color(0xFF2563EB),
                gradient: const [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                icon: Icons.delivery_dining_rounded,
                description: 'For delivery partners to accept store-to-door gigs from Navjeevan & More Provision, navigate delivery routes, and verify drop-offs.',
                actionText: 'Sign In / Register',
                onTap: () => onSelectPortal('delivery'),
              ),
              const SizedBox(height: 14),

              // 4. ADMIN PORTAL CARD
              _buildPortalCard(
                title: 'Admin Command Center',
                badge: 'ADMINISTRATORS ONLY',
                badgeColor: const Color(0xFF7C3AED),
                gradient: const [Color(0xFF4C1D95), Color(0xFF5B21B6)],
                icon: Icons.admin_panel_settings_rounded,
                description: 'For system administrators to oversee Navjeevan, More Provision, riders, customers, and supervise isolated portals.',
                actionText: 'Admin Sign In',
                onTap: () => onSelectPortal('admin'),
              ),
              const SizedBox(height: 20),

              // Android Installation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F291E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3DDC84).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.android, color: Color(0xFF3DDC84), size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Android Standalone Release APK',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Native release build with camera OCR & zero latency. Tap below to download directly to your Android device.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DDC84),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'Download SmartCart-Release.apk (53.1 MB)',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        onPressed: () {
                          openExternalUrl('/static/SmartCart.apk');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required String label,
    required IconData icon,
    required Color color,
    required String role,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withOpacity(0.6), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => onSelectPortal(role),
    );
  }

  Widget _buildPortalCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required List<Color> gradient,
    required IconData icon,
    required String description,
    required String actionText,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? badgeColor.withOpacity(0.6) : const Color(0xFF334155),
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: badgeColor.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Dedicated Portal Login',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: Text(
                        actionText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
