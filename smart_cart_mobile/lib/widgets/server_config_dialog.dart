import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ServerConfigDialog extends StatefulWidget {
  final VoidCallback? onSaved;

  const ServerConfigDialog({Key? key, this.onSaved}) : super(key: key);

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ServerConfigDialog(onSaved: onSaved),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pingServer() async {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isEmpty) {
      setState(() {
        _testResult = 'Please enter a valid URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse('$rawUrl/api/health')).timeout(
        const Duration(seconds: 6),
      );
      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _testSuccess = true;
          _testResult = '✅ Connected! Latency: ${stopwatch.elapsedMilliseconds}ms\nStatus: ${data['status']} • ${data['service']}';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = '⚠️ Server reached but returned HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testSuccess = false;
        _testResult = '❌ Cannot connect (${stopwatch.elapsedMilliseconds}ms):\n$e\n\n'
            '👉 If using Local PC: Check Windows Firewall or router AP isolation.\n'
            '👉 If using Render: Ensure URL starts with https:// and service is not spinning up.';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _applyAndSave() {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isNotEmpty) {
      ApiConfig.setCustomUrl(rawUrl);
    } else {
      ApiConfig.resetToDefault();
    }
    widget.onSaved?.call();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backend URL set to: ${ApiConfig.baseUrl}'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: const [
          Icon(Icons.dns_rounded, color: Color(0xFF059669), size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Backend API Server',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configure the FastAPI backend server address for this device:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'https://smart-cart-ai.onrender.com',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 10),

            // Quick preset chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi_rounded, size: 14),
                  label: const Text('Local PC (Hotspot)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'http://10.94.251.120:8000';
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 14),
                  label: const Text('Render Cloud', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'https://smart-cart-ai.onrender.com';
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Reset Default', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiConfig.defaultLocalUrl;
                      _testResult = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Test Ping Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isTesting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check_rounded, size: 18),
              label: Text(_isTesting ? 'Pinging Server...' : 'Test Connection (Ping)'),
              onPressed: _isTesting ? null : _pingServer,
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _testSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _applyAndSave,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

