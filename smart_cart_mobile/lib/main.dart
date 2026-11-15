import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/portal_gateway_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_portal_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/merchant/merchant_dashboard_screen.dart';
import 'screens/delivery/delivery_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() {
  runApp(const SmartCartMobileApp());
}

class SmartCartMobileApp extends StatelessWidget {
  const SmartCartMobileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Cart AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          primary: const Color(0xFF059669),
          secondary: const Color(0xFFF59E0B),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      home: const MainMobileShell(),
    );
  }
}

class MainMobileShell extends StatefulWidget {
  const MainMobileShell({Key? key}) : super(key: key);

  @override
  State<MainMobileShell> createState() => _MainMobileShellState();
}

class _MainMobileShellState extends State<MainMobileShell> {
  bool _showSplash = true;
  int? _actualAdminId; // Preserves Admin ID while in supervision mode
  String? _selectedPortal; // 'customer', 'merchant', 'delivery', 'admin' or null (Gateway)

  void _onRoleChanged() {
    setState(() {});
  }

  void _handleLogout() {
    final prevRole = ApiService().currentUser?.role;
    ApiService().logout();
    _actualAdminId = null;
    _selectedPortal = prevRole; // Stays on the dedicated portal auth screen
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out successfully.')),
    );
  }

  Future<void> _handleAdminSuperviseRole(String targetRole) async {
    final admin = ApiService().currentUser;
    if (admin == null || admin.role != 'admin') return;

    try {
      final adminId = admin.id;
      await ApiService().adminSuperviseRole(adminId, targetRole);
      setState(() {
        _actualAdminId = adminId;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👑 Admin Supervision Mode active: Inspecting ${targetRole.toUpperCase()} portal'),
            backgroundColor: const Color(0xFF7C3AED),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supervision error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _returnToAdminPanel() async {
    if (_actualAdminId == null) return;
    try {
      await ApiService().returnFromSupervision(_actualAdminId!);
      setState(() {
        _actualAdminId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Returned to Admin Control Center'),
            backgroundColor: Color(0xFF7C3AED),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error returning to admin: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () {
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }

    final user = ApiService().currentUser;

    // 1. If not logged in:
    if (user == null) {
      if (_selectedPortal == null) {
        // Show Portal Gateway (Select Your Portal)
        return PortalGatewayScreen(
          onSelectPortal: (portal) {
            setState(() {
              _selectedPortal = portal;
            });
          },
          onInstantLaunch: (portal) async {
            if (portal == 'merchant_more') {
              await ApiService().quickSwitchRole('merchant', storeId: 2);
            } else if (portal == 'merchant_navjeevan') {
              await ApiService().quickSwitchRole('merchant', storeId: 1);
            } else {
              await ApiService().quickSwitchRole(portal);
            }
            if (mounted) {
              setState(() {});
            }
          },
        );
      } else {
        // Show the chosen Dedicated Portal (Customer, Merchant, Delivery, or Admin)
        return AuthPortalScreen(
          portalRole: _selectedPortal!,
          onBackToGateway: () {
            setState(() {
              _selectedPortal = null;
            });
          },
          onAuthSuccess: _onRoleChanged,
        );
      }
    }

    // 2. If logged in: strictly route to the user's isolated portal!
    final isSupervising = _actualAdminId != null;

    Widget roleBody;
    String roleTitle;
    Color roleBadgeColor;

    switch (user.role) {
      case 'merchant':
        roleBody = const MerchantDashboardScreen();
        roleTitle = '🏪 Kirana Merchant Portal';
        roleBadgeColor = const Color(0xFFD97706);
        break;
      case 'delivery':
        roleBody = const DeliveryDashboardScreen();
        roleTitle = '🛵 Delivery Partner Portal';
        roleBadgeColor = const Color(0xFF2563EB);
        break;
      case 'admin':
        roleBody = AdminDashboardScreen(onSuperviseRole: _handleAdminSuperviseRole);
        roleTitle = '⚡ Admin Command Center';
        roleBadgeColor = const Color(0xFF7C3AED);
        break;
      case 'customer':
      default:
        roleBody = CustomerHomeScreen(onRefreshNeeded: _onRoleChanged);
        roleTitle = '🛒 Customer Grocery App';
        roleBadgeColor = const Color(0xFF059669);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleBadgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: TextStyle(color: roleBadgeColor, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            tooltip: 'Log Out of ${user.role.toUpperCase()}',
            onPressed: _handleLogout,
          ),
        ],
      ),
      // STRICT ISOLATION: No drawer for any customer or merchant. Portals cannot cross!
      drawer: null,
      body: Column(
        children: [
          // If Admin is inspecting another portal in supervision mode, show the top banner with Return button
          if (isSupervising)
            Container(
              color: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '👑 Admin Supervision: Inspecting ${user.role.toUpperCase()} Portal',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 12),
                    label: const Text('Return to Admin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                    onPressed: _returnToAdminPanel,
                  ),
                ],
              ),
            ),
          Expanded(child: roleBody),
        ],
      ),
    );
  }
}
