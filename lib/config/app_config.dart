/// Company details used across the app (header, enquiry buttons, PDF footer).
///
/// TODO(kreedum): replace the placeholder contact details below before
/// publishing. Everything else in the app reads from here.
class AppConfig {
  AppConfig._();

  static const String appName = 'Kreedum Construction';
  static const String brandWord = 'KREEDUM';
  static const String brandSub = 'CONSTRUCTION';
  static const String tagline = 'Sports courts & playground flooring';

  /// WhatsApp number in international format, digits only (no +, spaces or dashes).
  static const String whatsappNumber = '7570004258';

  /// Phone number for the "Call" button.
  static const String phoneNumber = '7570004258';

  /// Enquiry e-mail address.
  static const String email = 'kreedumindia@gmail.com';

  static const String website = 'https://kreedum.com';

  /// Shown on the Contact screen and the PDF footer. Leave empty to hide.
  static const String address = '';

  /// Pre-filled WhatsApp / e-mail text when no design is attached.
  static const String genericEnquiry =
      'Hi Kreedum Construction, I would like a quote for a sports court / playground floor.';
}
