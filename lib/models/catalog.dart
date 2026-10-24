import 'dart:convert';

import 'package:flutter/services.dart';

import 'palette.dart';

class FloorItem {
  FloorItem({
    required this.id,
    required this.title,
    required this.asset,
    required this.category,
    this.defaults = const {},
  });

  final String id;
  final String title;
  final String asset;
  final FloorCategory category;

  /// Default colour per zone key (e.g. {"court": #2C62E0}).
  final Map<String, Color> defaults;
}

class FloorCategory {
  FloorCategory({required this.id, required this.title, required this.subtitle, required this.icon, this.baseColor});

  final String id;
  final String title;
  final String subtitle;
  final String icon;

  /// Optional colour applied to every paintable area when a design opens
  /// (used to give the EPDM line-art a clean "unpainted" look).
  final Color? baseColor;
  final List<FloorItem> items = [];
}

/// Loads `assets/floors/catalog.json` and merges in any SVG found in
/// `assets/floors/<categoryId>/` that the catalog doesn't list yet — so a new
/// floor can be added just by dropping its SVG into the right folder.
class Catalog {
  Catalog(this.categories);

  final List<FloorCategory> categories;

  static Catalog? _cache;

  static Future<Catalog> load([AssetBundle? bundle]) async {
    if (_cache != null) return _cache!;
    final b = bundle ?? rootBundle;
    final json = jsonDecode(await b.loadString('assets/floors/catalog.json')) as Map<String, dynamic>;

    List<String> allAssets = const [];
    try {
      allAssets = (await AssetManifest.loadFromAssetBundle(b)).listAssets();
    } catch (_) {
      // Manifest unavailable (e.g. some tests) — fall back to catalog only.
    }

    final categories = <FloorCategory>[];
    for (final c in (json['categories'] as List).cast<Map<String, dynamic>>()) {
      final cat = FloorCategory(
        id: c['id'] as String,
        title: c['title'] as String,
        subtitle: (c['subtitle'] as String?) ?? '',
        icon: (c['icon'] as String?) ?? 'grid',
        baseColor: parseCssColor(c['baseColor'] as String?),
      );
      final listed = <String>{};
      for (final i in ((c['items'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        final asset = i['asset'] as String;
        if (allAssets.isNotEmpty && !allAssets.contains(asset)) continue; // file removed
        listed.add(asset);
        final defaults = <String, Color>{};
        (i['defaults'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
          final col = parseCssColor(v as String?);
          if (col != null) defaults[k] = col;
        });
        cat.items.add(
          FloorItem(
            id: i['id'] as String,
            title: i['title'] as String,
            asset: asset,
            category: cat,
            defaults: defaults,
          ),
        );
      }
      final folder = 'assets/floors/${cat.id}/';
      final extra =
          allAssets
              .where((a) => a.startsWith(folder) && a.toLowerCase().endsWith('.svg') && !listed.contains(a))
              .toList()
            ..sort();
      for (final a in extra) {
        final file = a.substring(folder.length, a.length - 4);
        cat.items.add(FloorItem(id: file, title: _titleFromFile(file), asset: a, category: cat));
      }
      if (cat.items.isNotEmpty) categories.add(cat);
    }
    return _cache = Catalog(categories);
  }

  static String _titleFromFile(String f) =>
      f.split(RegExp(r'[_\-\s]+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}
