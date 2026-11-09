import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Default base URL for our Python FastAPI backend
  // When running on Android emulator: 10.0.2.2
  // When running on Web / Desktop: 127.0.0.1
  // Can be adjusted dynamically in the app settings
  static String _customUrl = '';

  static String get baseUrl {
    if (_customUrl.isNotEmpty) return _customUrl;

    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null' && !origin.startsWith('file:')) {
        return origin;
      }
      return 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      // Direct connection to PC's local network IP for physical Android devices & emulators
      return 'http://10.50.194.120:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  static bool get isCustomUrlSet => _customUrl.isNotEmpty;
  static String get defaultLocalUrl => 'http://10.50.194.120:8000';

  static void setCustomUrl(String url) {
    _customUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static void resetToDefault() {
    _customUrl = '';
  }
}
