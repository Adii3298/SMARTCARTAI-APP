import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class RoleSwitcherDrawer extends StatelessWidget {
  final VoidCallback onRoleChanged;

  const RoleSwitcherDrawer({Key? key, required this.onRoleChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final isAdmin = user?.role == 'admin';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              user?.name ?? 'Guest User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              '${user?.userId ?? ''} • ${user?.role.toUpperCase() ?? 'LOGIN REQUIRED'}',
              style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ),
          ),

          // Admin sees all role switcher tiles; others see only their role info
          if (isAdmin) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '1-CLICK DEMO ROLE SWITCHER (ADMIN)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
            ),
            _buildRoleTile(context, '🛒 Customer', 'customer', Icons.shopping_basket_rounded),
            _buildRoleTile(context, '🏪 Kirana Merchant', 'merchant', Icons.storefront_rounded),
            _buildRoleTile(context, '🛵 Delivery Partner', 'delivery', Icons.delivery_dining_rounded),
            _buildRoleTile(context, '⚡ Platform Admin', 'admin', Icons.admin_panel_settings_rounded),
          ] else ...[
            // Non-admin users: show only their own role info, no switching
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Logged in as ${user?.role.toUpperCase() ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You have access to your ${user?.role ?? ""} portal only. '
                      'Please log out and log in with the correct credentials to access a different portal.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF059669)),
            title: const Text('Register Another Role', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            subtitle: const Text('Open 4-role registration screen', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              ApiService().logout();
              onRoleChanged();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              ApiService().logout();
              onRoleChanged();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_ethernet_rounded, color: Colors.teal),
            title: const Text('Backend API Server IP'),
            subtitle: Text(ApiConfig.baseUrl, style: const TextStyle(fontSize: 11)),
            onTap: () => _showServerSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTile(BuildContext context, String title, String role, IconData icon) {
    final isCurrent = ApiService().currentUser?.role == role;
    return ListTile(
      leading: Icon(icon, color: isCurrent ? const Color(0xFF059669) : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? const Color(0xFF059669) : Colors.black87,
        ),
      ),
      trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18) : null,
      onTap: () async {
        Navigator.pop(context);
        try {
          await ApiService().quickSwitchRole(role);
          onRoleChanged();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to switch role: $e')),
          );
        }
      },
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend API URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For Android Emulator use: http://10.0.2.2:8000\nFor Real Phone over WiFi use: http://<your-pc-ip>:8000',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Server URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setCustomUrl(controller.text);
              Navigator.pop(ctx);
              onRoleChanged();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
