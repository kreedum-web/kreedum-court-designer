import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/enquiry_service.dart';
import '../widgets/brand.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Future<void> go(Future<bool> f) async {
      if (!await f && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to handle this.')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: ListView(
        children: [
          Container(
            color: KColors.navy,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(markSize: 40),
                const SizedBox(height: 16),
                Text(AppConfig.tagline, style: text.bodyLarge!.copyWith(color: KColors.whiteA(0.75))),
                const SizedBox(height: 18),
                WhatsAppButton(
                  label: 'Message us on WhatsApp',
                  onPressed: () => go(EnquiryService.whatsapp(AppConfig.genericEnquiry)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _row(context, Icons.call_outlined, 'Call', AppConfig.phoneNumber, () => go(EnquiryService.call())),
          _row(
            context,
            Icons.mail_outline_rounded,
            'Email',
            AppConfig.email,
            () => go(EnquiryService.email(subject: 'Enquiry', body: AppConfig.genericEnquiry)),
          ),
          _row(
            context,
            Icons.language_rounded,
            'Website',
            AppConfig.website.replaceFirst(RegExp(r'^https?://'), ''),
            () => go(EnquiryService.website()),
          ),
          if (AppConfig.address.isNotEmpty) _row(context, Icons.place_outlined, 'Address', AppConfig.address, null),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Text(
              'This app works offline and does not collect or store any personal data. '
              'Designs, logos and enquiries stay on your device until you choose to share them.',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value, VoidCallback? onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: KColors.tint,
        child: Icon(icon, color: KColors.blue, size: 20),
      ),
      title: Text(label.toUpperCase(), style: KText.eyebrow(color: KColors.slateLight)),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleSmall),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: KColors.slateLight),
      onTap: onTap,
    );
  }
}
