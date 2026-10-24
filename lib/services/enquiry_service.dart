import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// WhatsApp / call / e-mail enquiries — no login, no backend.
class EnquiryService {
  EnquiryService._();

  static Future<bool> whatsapp(String message) => launchUrl(
    Uri.parse('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent(message)}'),
    mode: LaunchMode.externalApplication,
  );

  static Future<bool> call() =>
      launchUrl(Uri(scheme: 'tel', path: AppConfig.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '')));

  static Future<bool> email({required String subject, required String body}) => launchUrl(
    // Built by hand so spaces become %20 (mail apps show '+' literally).
    Uri.parse(
      'mailto:${AppConfig.email}'
      '?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    ),
  );

  static Future<bool> website() => launchUrl(Uri.parse(AppConfig.website), mode: LaunchMode.externalApplication);
}
