import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';

void openExternalUrl(String url) {
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'SmartCart-Release.apk')
      ..target = '_blank';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } catch (e) {
    try {
      html.window.open(url, '_blank');
    } catch (_) {}
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
