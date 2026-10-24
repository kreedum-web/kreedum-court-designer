import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/enquiry_service.dart';
import '../services/export_service.dart';

/// Bottom sheet with WhatsApp / call / e-mail options.
/// When [snapshot] is given, the design and its colours go with the enquiry.
Future<void> showEnquirySheet(BuildContext context, {Future<DesignSnapshot> Function()? snapshot}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _EnquirySheet(snapshot: snapshot),
  );
}

class _EnquirySheet extends StatefulWidget {
  const _EnquirySheet({this.snapshot});
  final Future<DesignSnapshot> Function()? snapshot;

  @override
  State<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends State<_EnquirySheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open that app ($e)')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _text() async =>
      widget.snapshot == null ? AppConfig.genericEnquiry : (await widget.snapshot!()).enquiryText();

  Future<void> _check(Future<bool> launched) async {
    if (!await launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to handle this.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDesign = widget.snapshot != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GET A QUOTE', style: KText.eyebrow()),
            const SizedBox(height: 6),
            Text(
              hasDesign ? 'Send this design to our team' : 'Talk to our team',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              hasDesign
                  ? 'We\'ll reply with pricing, samples and timelines. Your colour choices are included automatically.'
                  : 'Tell us about your court or playground and we\'ll get back with pricing and options.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (hasDesign) ...[
              WhatsAppTile(
                busy: _busy,
                onTap: () => _run(() async => ExportService.shareImage(await widget.snapshot!())),
              ),
              const SizedBox(height: 10),
            ],
            _Tile(
              icon: Icons.chat_outlined,
              iconColor: KColors.whatsappText,
              iconBg: KColors.whatsapp.withValues(alpha: 0.18),
              title: 'Chat on WhatsApp',
              subtitle: hasDesign ? 'Opens a chat with your colour list filled in' : 'Opens a chat with us',
              onTap: _busy ? null : () => _run(() async => _check(EnquiryService.whatsapp(await _text()))),
            ),
            _Tile(
              icon: Icons.call_outlined,
              title: 'Call us',
              subtitle: AppConfig.phoneNumber,
              onTap: _busy ? null : () => _run(() => _check(EnquiryService.call())),
            ),
            _Tile(
              icon: Icons.mail_outline_rounded,
              title: 'Email us',
              subtitle: AppConfig.email,
              onTap: _busy
                  ? null
                  : () => _run(
                      () async => _check(
                        EnquiryService.email(
                          subject: hasDesign ? 'Quote request – ${(await widget.snapshot!()).title}' : 'Quote request',
                          body: await _text(),
                        ),
                      ),
                    ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

/// Primary "send the picture" action — uses the system share sheet so the user
/// can pick WhatsApp (or WhatsApp Business) with the image attached.
class WhatsAppTile extends StatelessWidget {
  const WhatsAppTile({super.key, required this.onTap, this.busy = false});
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KColors.whatsapp,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.send_rounded, color: KColors.whatsappText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send design image',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: KColors.whatsappText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick WhatsApp in the share menu',
                      style: Theme.of(context).textTheme.bodySmall!
                          .copyWith(color: KColors.whatsappText.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: KColors.whatsappText),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = KColors.blue,
    this.iconBg = KColors.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: iconBg,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.labelLarge),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded, color: KColors.slateLight),
      onTap: onTap,
    );
  }
}
