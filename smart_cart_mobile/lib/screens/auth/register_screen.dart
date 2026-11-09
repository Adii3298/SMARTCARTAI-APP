import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisteredSuccess;

  const RegisterScreen({Key? key, required this.onRegisteredSuccess}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _selectedRole = 'customer';
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController(text: 'Indiranagar');
  final _pincodeController = TextEditingController(text: '560038');

  // Merchant specific
  final _storeNameController = TextEditingController();
  final _upiController = TextEditingController();

  // Delivery specific
  String _vehicleType = 'Bike';
  final _vehicleNumberController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty || _mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Name and Mobile Number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService().register(
        role: _selectedRole,
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        area: _areaController.text.trim(),
        pincode: _pincodeController.text.trim(),
        storeName: _storeNameController.text.trim().isNotEmpty ? _storeNameController.text.trim() : null,
        upiId: _upiController.text.trim().isNotEmpty ? _upiController.text.trim() : null,
        vehicleType: _vehicleType,
        vehicleNumber: _vehicleNumberController.text.trim().isNotEmpty ? _vehicleNumberController.text.trim() : null,
      );

      // Show simulated SMS credentials dialog (Step 1 requirement!)
      if (mounted) {
        _showSimulatedSmsDialog(res['sms_notification'], res['credentials']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSimulatedSmsDialog(String smsText, Map<String, dynamic> credentials) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Simulated SMS Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                smsText,
                style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('Copy User ID: ${credentials['user_id']}'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: credentials['user_id']));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied User ID: ${credentials['user_id']}')),
                );
              },
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.password_rounded, size: 16),
              label: Text('Copy Password: ${credentials['password']}'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: credentials['password']));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied Password: ${credentials['password']}')),
                );
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Back to login screen
            },
            child: const Text('Proceed to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('4-Role Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role Selector
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Select Role',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: const Color(0xFFECFDF5),
              ),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('🛒 Customer (Shopper)')),
                DropdownMenuItem(value: 'merchant', child: Text('🏪 Merchant (Kirana Owner)')),
                DropdownMenuItem(value: 'delivery', child: Text('🛵 Delivery Partner (Rider)')),
                DropdownMenuItem(value: 'admin', child: Text('⚡ Platform Admin')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number *',
                hintText: '10-digit mobile number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password (Optional - defaults to ${_selectedRole}@123)',
                hintText: 'Choose your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaController,
                    decoration: InputDecoration(
                      labelText: 'Area / Locality',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Street Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            // Merchant conditional fields
            if (_selectedRole == 'merchant') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏪 Store Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(labelText: 'Kirana Store Name', filled: true, fillColor: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _upiController,
                      decoration: const InputDecoration(labelText: 'Store UPI ID for Payments', filled: true, fillColor: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Delivery conditional fields
            if (_selectedRole == 'delivery') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🛵 Delivery Fleet Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: const InputDecoration(labelText: 'Vehicle Type', filled: true, fillColor: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'Bike', child: Text('Motorbike')),
                        DropdownMenuItem(value: 'Scooter', child: Text('Scooter')),
                        DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _vehicleType = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(labelText: 'Vehicle Plate Number', hintText: 'KA-04-XX-1234', filled: true, fillColor: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Complete Registration & Receive Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
