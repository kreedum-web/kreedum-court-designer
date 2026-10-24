import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/catalog.dart';
import '../widgets/brand.dart';
import '../widgets/enquiry_sheet.dart';
import '../widgets/floor_thumbnail.dart';
import 'category_screen.dart';
import 'contact_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Catalog> _catalog = Catalog.load();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: FutureBuilder<Catalog>(
        future: _catalog,
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(onQuote: () => showEnquirySheet(context))),
              if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Could not load designs.\n${snap.error}', textAlign: TextAlign.center)),
                )
              else if (!snap.hasData)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CHOOSE A FLOOR', style: KText.eyebrow()),
                        const SizedBox(height: 6),
                        Text('What are we building?', style: text.headlineSmall),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverList.separated(
                    itemCount: snap.data!.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _CategoryCard(category: snap.data!.categories[i]),
                  ),
                ),
                SliverToBoxAdapter(child: _HowItWorks()),
                SliverToBoxAdapter(child: _Footer()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onQuote});
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KColors.navy, KColors.navy, KColors.blueDark],
          stops: [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandLockup(),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Contact',
                    color: KColors.white,
                    icon: const Icon(Icons.support_agent_rounded),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COURT & FLOOR VISUALISER', style: KText.eyebrow(color: KColors.accentLight)),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: KText.display(32, color: KColors.white),
                        children: const [
                          TextSpan(text: 'See your court\nbefore we '),
                          TextSpan(
                            text: 'build it.',
                            style: TextStyle(color: KColors.accentLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pick a court or playground design, tap to colour every zone, add your logo '
                      'and send it to us for a quote.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: KColors.whiteA(0.72)),
                    ),
                    const SizedBox(height: 20),
                    WhatsAppButton(label: 'Get a quote', onPressed: onQuote),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final FloorCategory category;

  IconData get _icon => switch (category.icon) {
    'sports_tennis' => Icons.sports_tennis_rounded,
    'toys' => Icons.toys_rounded,
    _ => Icons.grid_view_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = category.items.take(3).toList();
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: category)));

    return Material(
      color: KColors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KColors.paperDim),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 128,
                child: Row(
                  children: [
                    for (final item in preview)
                      Expanded(
                        child: FloorThumbnail(item: item, padding: const EdgeInsets.all(8)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: KColors.tint,
                      child: Icon(_icon, color: KColors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.title, style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text('${category.items.length} designs · ${category.subtitle}', style: text.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: KColors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const steps = [
      (Icons.touch_app_outlined, 'Tap to colour', 'Choose a shade, then tap any zone of the floor.'),
      (Icons.add_photo_alternate_outlined, 'Add your logo', 'Upload your school, club or society logo.'),
      (Icons.ios_share_rounded, 'Share or print', 'Export as an image or PDF proposal.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW IT WORKS', style: KText.eyebrow()),
          const SizedBox(height: 12),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.$1, color: KColors.blue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$2, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(s.$3, style: text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      color: KColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLockup(markSize: 28),
            const SizedBox(height: 12),
            Text(
              AppConfig.tagline,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: KColors.whiteA(0.7)),
            ),
            const SizedBox(height: 16),
            WhatsAppButton(label: 'Message us on WhatsApp', onPressed: () => showEnquirySheet(context)),
          ],
        ),
      ),
    );
  }
}
