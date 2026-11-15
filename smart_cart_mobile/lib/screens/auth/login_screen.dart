import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  String? _captchaId;
  String? _captchaBase64;
  bool _isLoading = false;
  bool _isLoadingCaptcha = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  Future<void> _loadCaptcha() async {
    setState(() => _isLoadingCaptcha = true);
    try {
      final res = await ApiService().fetchCaptcha();
      setState(() {
        _captchaId = res['captcha_id'];
        _captchaBase64 = res['image_base64'];
        _captchaController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load CAPTCHA: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCaptcha = false);
    }
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

    setState(() => _isLoading = true);
    try {
      await ApiService().login(
        loginId: _loginIdController.text.trim(),
        password: _passwordController.text.trim(),
        captchaId: _captchaId ?? '',
        captchaText: _captchaController.text.trim(),
      );
      widget.onLoginSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
      _loadCaptcha(); // Refresh on failure
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _quickLogin(String role) async {
    setState(() => _isLoading = true);
    try {
      await ApiService().quickSwitchRole(role);
      widget.onLoginSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quick login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Smart Cart AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'Local Kirana Hyperlocal Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 28),

                // Login Form Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In with CAPTCHA',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _loginIdController,
                          decoration: InputDecoration(
                            labelText: 'User ID or Mobile Number',
                            hintText: 'e.g. CUST1001 or 9876543210',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                              icon: const Icon(Icons.lock_reset_rounded, size: 15, color: Color(0xFF059669)),
                              label: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _openForgotPasswordDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Interactive CAPTCHA Container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text('CAPTCHA Verification', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    onPressed: _isLoadingCaptcha ? null : _loadCaptcha,
                                  ),
                                ],
                              ),
                              if (_captchaBase64 != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(_captchaBase64!.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 48,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _captchaController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'ENTER 5 CHARACTERS',
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
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Verify CAPTCHA & Enter', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 1-Click Demo Logins
                const Text(
                  'OR 1-CLICK DEMO LOGIN:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.shopping_basket_rounded, size: 14, color: Color(0xFF059669)),
                      label: const Text('Customer', style: TextStyle(fontSize: 11)),
                      onPressed: () => _quickLogin('customer'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.storefront_rounded, size: 14, color: Colors.amber),
                      label: const Text('Merchant', style: TextStyle(fontSize: 11)),
                      onPressed: () => _quickLogin('merchant'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.delivery_dining_rounded, size: 14, color: Colors.blue),
                      label: const Text('Delivery', style: TextStyle(fontSize: 11)),
                      onPressed: () => _quickLogin('delivery'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.purple),
                      label: const Text('Admin', style: TextStyle(fontSize: 11)),
                      onPressed: () => _quickLogin('admin'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New to Smart Cart AI?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => RegisterScreen(onRegisteredSuccess: widget.onLoginSuccess),
                          ),
                        );
                      },
                      child: const Text('Register Here', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
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

  void _openForgotPasswordDialog() {
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
                      color: const Color(0xFF059669).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Account Recovery',
                          style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
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

                      TextField(
                        controller: loginIdCtrl,
                        enabled: !otpSent && !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'User ID or Mobile Number',
                          hintText: 'e.g. 9876543210 or MERC2001',
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
                            backgroundColor: const Color(0xFF059669),
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
                                    final res = await ApiService().requestPasswordReset(id);
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
