import 'package:url_launcher/url_launcher.dart';

Future<bool> openCustomerDialer(String phone) async {
  try {
    return await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // A device without a dialer may reject the intent.
    return false;
  }
}
