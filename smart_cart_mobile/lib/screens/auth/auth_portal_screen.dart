import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/server_config_dialog.dart';

class AuthPortalScreen extends StatefulWidget {
  final String portalRole; // 'customer', 'merchant', 'delivery', 'admin'
  final VoidCallback onAuthSuccess;
  final VoidCallback? onBackToGateway;
  final int initialTabIndex; // 0 = Sign In, 1 = Register

  const AuthPortalScreen({
    Key? key,
    required this.portalRole,
    required this.onAuthSuccess,
    this.onBackToGateway,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<AuthPortalScreen> createState() => _AuthPortalScreenState();
}

class _AuthPortalScreenState extends State<AuthPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Registration State ---
  final _regNameController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regAddressController = TextEditingController();
  final _regAreaController = TextEditingController();
  final _regPincodeController = TextEditingController();

  // Password visibility states
  bool _obscureRegPassword = true;
  bool _obscureLoginPassword = true;

  // Merchant specific
  final _storeNameController = TextEditingController();
  final _upiController = TextEditingController();

  // Delivery specific
  String _vehicleType = 'Bike';
  final _vehicleNumberController = TextEditingController();

  bool _isRegistering = false;

  // --- Login State ---
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  String? _captchaId;
  String? _captchaBase64;
  String? _offlineCaptchaText;
  bool _isLoadingCaptcha = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // All portals (Customer, Merchant, Delivery, Admin) support Sign In and Registration
    const tabCount = 2;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: widget.initialTabIndex);
    
    // Instant zero-delay local security CAPTCHA on frame 0 (never shows a spinner)
    final instant = ApiService.generateLocalCaptcha();
    _captchaId = instant['captcha_id'];
    _offlineCaptchaText = instant['offline_text'];
    _isLoadingCaptcha = false;

    // Concurrently fetch high-contrast visual backend CAPTCHA
    _loadCaptcha();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameController.dispose();
    _regMobileController.dispose();
    _regPasswordController.dispose();
    _regEmailController.dispose();
    _regAddressController.dispose();
    _regAreaController.dispose();
    _regPincodeController.dispose();
    _storeNameController.dispose();
    _upiController.dispose();
    _vehicleNumberController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha({bool manualRefresh = false}) async {
    if (manualRefresh) {
      // If user tapped refresh, immediately show fresh local captcha so there is 0 latency
      final fresh = ApiService.generateLocalCaptcha();
      setState(() {
        _captchaId = fresh['captcha_id'];
        _offlineCaptchaText = fresh['offline_text'];
        _captchaBase64 = null;
        _captchaController.clear();
      });
    }
    
    try {
      final res = await ApiService().fetchCaptcha();
      if (mounted) {
        setState(() {
          _captchaId = res['captcha_id'];
          _captchaBase64 = res['image_base64'];
          _offlineCaptchaText = res['offline_text'];
          _isLoadingCaptcha = false;
        });
      }
    } catch (e) {
      if (mounted && _captchaId == null) {
        final fallback = ApiService.generateLocalCaptcha();
        setState(() {
          _captchaId = fallback['captcha_id'];
          _offlineCaptchaText = fallback['offline_text'];
          _isLoadingCaptcha = false;
        });
      }
    }
  }

  String _getDemoCredentialText() {
    switch (widget.portalRole) {
      case 'admin':
        return 'Mobile: 9999900000  •  Pwd: admin123';
      case 'customer':
        return 'Mobile: 9876543210  •  Pwd: cust123';
      case 'merchant':
        return 'Mobile: 9845012345  •  Pwd: merc123';
      case 'delivery':
        return 'Mobile: 9731011223  •  Pwd: delv123';
      default:
        return '';
    }
  }

  void _fillDemoCredentials() {
    switch (widget.portalRole) {
      case 'admin':
        _loginIdController.text = '9999900000';
        _passwordController.text = 'admin123';
        break;
      case 'customer':
        _loginIdController.text = '9876543210';
        _passwordController.text = 'cust123';
        break;
      case 'merchant':
        _loginIdController.text = '9845012345';
        _passwordController.text = 'merc123';
        break;
      case 'delivery':
        _loginIdController.text = '9731011223';
        _passwordController.text = 'delv123';
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.portalRole.toUpperCase()} credentials filled! Now enter the CAPTCHA below.'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_regNameController.text.trim().isEmpty || _regMobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Full Name and Mobile Number')),
      );
      return;
    }

    if (_regMobileController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    if (_regPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a password for your account')),
      );
      return;
    }

    if (_regPasswordController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 4 characters long')),
      );
      return;
    }

    setState(() => _isRegistering = true);
    try {
      final customPassword = _regPasswordController.text.trim();
      final res = await ApiService().register(
        role: widget.portalRole,
        name: _regNameController.text.trim(),
        mobile: _regMobileController.text.trim(),
        password: customPassword,
        email: _regEmailController.text.trim().isNotEmpty ? _regEmailController.text.trim() : null,
        address: _regAddressController.text.trim().isNotEmpty ? _regAddressController.text.trim() : null,
        area: _regAreaController.text.trim().isNotEmpty ? _regAreaController.text.trim() : null,
        pincode: _regPincodeController.text.trim().isNotEmpty ? _regPincodeController.text.trim() : null,
        storeName: _storeNameController.text.trim().isNotEmpty ? _storeNameController.text.trim() : null,
        vehicleType: _vehicleType,
        vehicleNumber: _vehicleNumberController.text.trim().isNotEmpty ? _vehicleNumberController.text.trim() : null,
      );

      if (mounted) {
        _showSimulatedSmsDialog(res['sms_notification'], res['credentials']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showSimulatedSmsDialog(String smsText, Map<String, dynamic> credentials) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Simulated SMS Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('From: VK-SMRTRT • Just now', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'REGISTRATION CONFIRMED (+91-${credentials['mobile']})',
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    smsText,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SAVE YOUR CREDENTIALS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('User ID: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SelectableText('${credentials['user_id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      const Spacer(),
                      const Text('Password: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SelectableText(
                        '${credentials['password'] ?? credentials['default_password'] ?? _regPasswordController.text.trim()}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final registeredPassword = '${credentials['password'] ?? credentials['default_password'] ?? _regPasswordController.text.trim()}';
              _loginIdController.text = '${credentials['user_id'] ?? credentials['mobile'] ?? _regMobileController.text.trim()}';
              _passwordController.text = registeredPassword;
              _tabController.animateTo(0);
              _loadCaptcha();
            },
            child: const Text('Proceed to Sign In with CAPTCHA ➔', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_loginIdController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter User ID / Mobile and Password')),
      );
      return;
    }

    if (_captchaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please solve and enter the CAPTCHA')),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      await ApiService().login(
        loginId: _loginIdController.text.trim(),
        password: _passwordController.text.trim(),
        captchaId: _captchaId ?? '',
        captchaText: _captchaController.text.trim(),
        portal: widget.portalRole,
      );
      widget.onAuthSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadCaptcha();
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    String portalTitle;
    String portalSubtitle;
    IconData portalIcon;

    switch (widget.portalRole) {
      case 'merchant':
        themeColor = const Color(0xFFD97706);
        portalTitle = 'Kirana Merchant Portal';
        portalSubtitle = 'Store Owners: Confirm grocery orders & live stock inventory';
        portalIcon = Icons.storefront_rounded;
        break;
      case 'delivery':
        themeColor = const Color(0xFF2563EB);
        portalTitle = 'Delivery Fleet Portal';
        portalSubtitle = 'Riders: Accept gigs, route delivery & verify 6-digit OTP';
        portalIcon = Icons.delivery_dining_rounded;
        break;
      case 'admin':
        themeColor = const Color(0xFF7C3AED);
        portalTitle = 'Admin Command Center';
        portalSubtitle = 'System Administrators: Oversee nodes, users & GMV';
        portalIcon = Icons.admin_panel_settings_rounded;
        break;
      case 'customer':
      default:
        themeColor = const Color(0xFF059669);
        portalTitle = 'Customer Grocery App';
        portalSubtitle = 'Shoppers: Scan handwritten lists, check local Kirana stock & order';
        portalIcon = Icons.shopping_basket_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Brand Bar with Back to All Portals Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      if (widget.onBackToGateway != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                          tooltip: 'Return to Portal Selection',
                          onPressed: widget.onBackToGateway,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, themeColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(portalIcon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              portalTitle,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              portalSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.portalRole.toUpperCase(),
                          style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.settings_ethernet_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Backend Server Settings',
                        onPressed: () => ServerConfigDialog.show(context, onSaved: () {
                          if (mounted) _loadCaptcha();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segmented Tabs (All 4 Portals have Sign In & Register)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: themeColor,
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      dividerColor: Colors.transparent,
                      tabs: [
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_rounded, size: 15),
                              SizedBox(width: 6),
                              Text('1. Sign In (CAPTCHA)'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_alt_1_rounded, size: 15),
                              const SizedBox(width: 6),
                              Text('2. Register ${widget.portalRole == "customer" ? "Shopper" : widget.portalRole.capitalize()}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(themeColor),
                  _buildRegistrationTab(themeColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PORTAL-SCOPED REGISTRATION SCREEN
  // ==========================================
  Widget _buildRegistrationTab(Color themeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Registration Form Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${widget.portalRole.toUpperCase()} REGISTRATION',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: themeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Common Contact Details
                  TextField(
                    controller: _regNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'Enter full name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _regMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number (10 Digits) *',
                      hintText: 'Enter 10-digit mobile number',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Create Password for Portal Login
                  TextField(
                    controller: _regPasswordController,
                    obscureText: _obscureRegPassword,
                    decoration: InputDecoration(
                      labelText: 'Create Login Password *',
                      hintText: 'Enter password (min 4 characters)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _regEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address (Optional)',
                      hintText: 'Enter email address (optional)',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _regAddressController,
                    decoration: InputDecoration(
                      labelText: widget.portalRole == 'customer' ? 'Delivery Address *' : 'Store / Operations Address *',
                      hintText: 'House / Flat No., Street, Landmark',
                      prefixIcon: const Icon(Icons.home_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _regAreaController,
                          decoration: InputDecoration(
                            labelText: 'Neighborhood / Area',
                            hintText: 'Area or Locality',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _regPincodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Pincode',
                            hintText: '6-digit Pincode',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Merchant Extra Fields (ONLY FOR MERCHANT)
                  if (widget.portalRole == 'merchant') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: Color(0xFFD97706), size: 16),
                              SizedBox(width: 6),
                              Text('KIRANA STORE PROFILE', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _storeNameController,
                            decoration: InputDecoration(
                              labelText: 'Kirana Store Name *',
                              hintText: 'e.g. Navjeevan Supermart / More Provision',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _upiController,
                            decoration: InputDecoration(
                              labelText: 'Store UPI ID for Instant Settlements',
                              hintText: 'e.g. navjeevan@okaxis or moreprovision@okhdfcbank',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Delivery Extra Fields (ONLY FOR DELIVERY)
                  if (widget.portalRole == 'delivery') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 16),
                              SizedBox(width: 6),
                              Text('DELIVERY FLEET DETAILS', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _vehicleType,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Type',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Bike', child: Text('🏍️ Motorbike')),
                              DropdownMenuItem(value: 'Scooter', child: Text('🛵 Scooter / EV')),
                              DropdownMenuItem(value: 'Bicycle', child: Text('🚲 Bicycle')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _vehicleType = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _vehicleNumberController,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Plate Number',
                              hintText: 'e.g. KA-04-EK-9821',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: _isRegistering ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isRegistering
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_to_mobile_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Register ${widget.portalRole.toUpperCase()} & Receive SMS',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: Text(
                'Already have User ID & Password? Sign In with CAPTCHA →',
                style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PORTAL-SCOPED SIGN IN SCREEN
  // ==========================================
  Widget _buildLoginTab(Color themeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Login Form Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'SIGN IN TO ${widget.portalRole.toUpperCase()} PORTAL',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: themeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Demo Credentials Helper Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 18, color: themeColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Default Pre-configured Account:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getDemoCredentialText(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: _fillDemoCredentials,
                          child: const Text('Auto-Fill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  TextField(
                    controller: _loginIdController,
                    decoration: InputDecoration(
                      labelText: '${widget.portalRole.capitalize()} User ID or Registered Mobile',
                      hintText: 'Enter User ID or 10-digit Mobile',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureLoginPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.lock_reset_rounded, size: 15, color: themeColor),
                        label: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _openForgotPasswordDialog(context, themeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // CAPTCHA Container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 16, color: themeColor),
                            const SizedBox(width: 6),
                            const Text('Interactive Visual CAPTCHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              tooltip: 'Refresh CAPTCHA',
                              onPressed: () => _loadCaptcha(manualRefresh: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (_captchaBase64 != null)
                          Container(
                            height: 75,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFFAFCFF),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_captchaBase64!.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        else if (_offlineCaptchaText != null)
                          Container(
                            height: 75,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    _offlineCaptchaText!.length,
                                    (i) => Text(
                                      _offlineCaptchaText![i],
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                        color: [
                                          const Color(0xFF0F172A),
                                          const Color(0xFF1E3A8A),
                                          const Color(0xFF047857),
                                          const Color(0xFFB45309),
                                          const Color(0xFF6D28D9),
                                        ][i % 5],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('LOCAL SECURITY CODE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_isLoadingCaptcha)
                          const SizedBox(
                            height: 75,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else
                          InkWell(
                            onTap: _loadCaptcha,
                            child: Container(
                              height: 75,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.refresh_rounded, color: Color(0xFFDC2626), size: 22),
                                  SizedBox(height: 4),
                                  Text(
                                    'Cannot connect to backend. Tap to reload CAPTCHA',
                                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: _captchaController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 15),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'ENTER 5 CHARACTERS',
                            hintStyle: const TextStyle(letterSpacing: 1, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _isLoggingIn ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoggingIn
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Verify CAPTCHA & Enter ${widget.portalRole.capitalize()} Portal', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Role Protection Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_rounded, size: 16, color: themeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Role Protected: Only ${widget.portalRole.toUpperCase()} accounts can log in here. Non-${widget.portalRole} accounts are rejected.',
                    style: TextStyle(fontSize: 11, color: themeColor, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: Text(
                'Don\'t have an account? Register ${widget.portalRole == "customer" ? "New Shopper" : widget.portalRole.capitalize()} →',
                style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openForgotPasswordDialog(BuildContext context, Color themeColor) {
    final loginIdCtrl = TextEditingController(text: _loginIdController.text.trim());
    final otpCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    bool otpSent = false;
    bool isSubmitting = false;
    String? maskedMobile;
    String? demoOtp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: themeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset Password',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.portalRole.toUpperCase()} Account Recovery',
                          style: TextStyle(fontSize: 11, color: themeColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter your User ID or registered Mobile number to receive a 6-digit recovery OTP code.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 14),

                      // Step 1: Login ID Field
                      TextField(
                        controller: loginIdCtrl,
                        enabled: !otpSent && !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'User ID or Mobile Number',
                          hintText: widget.portalRole == 'customer'
                              ? 'e.g. 9876543210'
                              : widget.portalRole == 'merchant'
                                  ? 'e.g. MERC2001 or 9845012345'
                                  : 'e.g. DELV3001 or 9845033445',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: otpSent ? Colors.grey.shade100 : Colors.white,
                        ),
                      ),

                      if (!otpSent) ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            isSubmitting ? 'Sending Code...' : 'Send Recovery OTP',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final id = loginIdCtrl.text.trim();
                                  if (id.isEmpty) {
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      const SnackBar(content: Text('Please enter your User ID or Mobile number')),
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    final res = await ApiService().requestPasswordReset(id, portal: widget.portalRole);
                                    setDialogState(() {
                                      otpSent = true;
                                      maskedMobile = res['masked_mobile'];
                                      demoOtp = res['otp'];
                                      otpCtrl.text = res['otp'] ?? '';
                                      isSubmitting = false;
                                    });
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                    );
                                  }
                                },
                        ),
                      ],

                      // Step 2: OTP and New Password Fields
                      if (otpSent) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'OTP generated for $maskedMobile',
                                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              if (demoOtp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Demo OTP Code: $demoOtp (Auto-filled below)',
                                  style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: otpCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: '6-Digit OTP Code',
                            prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: newPasswordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: confirmPasswordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text(
                            isSubmitting ? 'Updating...' : 'Set New Password',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final otp = otpCtrl.text.trim();
                                  final newPwd = newPasswordCtrl.text.trim();
                                  final confirmPwd = confirmPasswordCtrl.text.trim();

                                  if (otp.length != 6) {
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      const SnackBar(content: Text('Please enter valid 6-digit OTP')),
                                    );
                                    return;
                                  }

                                  if (newPwd.length < 4) {
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      const SnackBar(content: Text('Password must be at least 4 characters long')),
                                    );
                                    return;
                                  }

                                  if (newPwd != confirmPwd) {
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      const SnackBar(content: Text('Passwords do not match')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    final res = await ApiService().submitPasswordReset(
                                      loginId: loginIdCtrl.text.trim(),
                                      otp: otp,
                                      newPassword: newPwd,
                                    );
                                    Navigator.pop(dialogCtx);
                                    _loginIdController.text = loginIdCtrl.text.trim();
                                    _passwordController.text = newPwd;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Password updated! Solve CAPTCHA to sign in.'),
                                        backgroundColor: const Color(0xFF059669),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    _loadCaptcha();
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                    );
                                  }
                                },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
