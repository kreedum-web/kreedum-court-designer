import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/enquiry_service.dart';
import '../services/export_service.dart';
import 'brand.dart';

/// Contact / quote sheet opened from the top-right support icon.
/// When [snapshot] is given (from the editor), the design and its colours
/// go with the enquiry.
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

  bool get _hasDesign => widget.snapshot != null;

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

  Future<String> _text() async => _hasDesign ? (await widget.snapshot!()).enquiryText() : AppConfig.genericEnquiry;

  Future<void> _check(Future<bool> launched) async {
    if (!await launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to handle this.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasDesign) ...[
              Text('GET A QUOTE', style: KText.eyebrow()),
              const SizedBox(height: 6),
              Text('Send this design to our team', style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'We\'ll reply with pricing, samples and timelines. Your colour choices are included automatically.',
                style: text.bodyMedium,
              ),
            ] else ...[
              const BrandLockup(onDark: false, markSize: 30),
              const SizedBox(height: 14),
              Text('Talk to our team', style: text.titleLarge),
              const SizedBox(height: 4),
              Text('Pricing, samples and site visits for courts and playground floors.', style: text.bodyMedium),
            ],
            const SizedBox(height: 12),
            if (_hasDesign)
              _Tile(
                icon: Icons.send_rounded,
                iconColor: KColors.whatsappText,
                iconBg: KColors.whatsapp.withValues(alpha: 0.18),
                title: 'Send design image',
                subtitle: 'Pick WhatsApp (or any app) in the share menu',
                onTap: _busy ? null : () => _run(() async => ExportService.shareImage(await widget.snapshot!())),
              ),
            _Tile(
              icon: Icons.chat_outlined,
              iconColor: KColors.whatsappText,
              iconBg: KColors.whatsapp.withValues(alpha: 0.18),
              title: 'Chat on WhatsApp',
              subtitle: _hasDesign
                  ? 'Opens a chat with your colour list filled in'
                  : 'Usually replies within a few hours',
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
                          subject: _hasDesign ? 'Quote request – ${(await widget.snapshot!()).title}' : 'Enquiry',
                          body: await _text(),
                        ),
                      ),
                    ),
            ),
            if (!_hasDesign)
              _Tile(
                icon: Icons.language_rounded,
                title: 'Website',
                subtitle: AppConfig.website.replaceFirst(RegExp(r'^https?://'), ''),
                onTap: _busy ? null : () => _run(() => _check(EnquiryService.website())),
              ),
            if (!_hasDesign && AppConfig.address.isNotEmpty)
              _Tile(icon: Icons.place_outlined, title: 'Address', subtitle: AppConfig.address, onTap: null),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (!_hasDesign)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('This app works offline and does not collect any personal data.', style: text.bodySmall),
              ),
          ],
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
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: KColors.slateLight),
      onTap: onTap,
    );
  }
}
