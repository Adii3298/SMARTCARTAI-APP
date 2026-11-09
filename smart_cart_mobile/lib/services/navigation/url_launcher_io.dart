import 'package:url_launcher/url_launcher.dart';

void openExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    // Fallback
  }
}

Future<bool> launchUpiIntent(String upiUriString) async {
  try {
    final uri = Uri.parse(upiUriString);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    return false;
  }
}
