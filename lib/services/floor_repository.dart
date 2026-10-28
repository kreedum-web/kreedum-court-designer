import 'package:flutter/services.dart';
import 'dart:ui' show Color;
import '../models/catalog.dart';
import 'floor_document.dart';

/// Loads floor SVGs and works out the colours a design opens with.
class FloorRepository {
  FloorRepository._();

  static final Map<String, Future<String>> _thumbs = {};

  static Future<String> raw(String asset) => rootBundle.loadString(asset);

  static Future<FloorDocument> open(FloorItem item) async => FloorDocument.parse(await raw(item.asset));

 /// Start every paintable area neutral. User-picked colours are applied by the
/// editor; SVG strokes/markings remain visible.
static Map<int, Color> initialColors(FloorDocument doc, FloorItem item) => {
  for (final z in doc.zones) z.index: const Color(0xFFEEF1F8),
};

  /// Rendered SVG for list thumbnails (cached for the app session).
  static Future<String> thumbnail(FloorItem item) => _thumbs.putIfAbsent(item.asset, () async {
    final doc = await open(item);
    return doc.render(initialColors(doc, item));
  });
}
