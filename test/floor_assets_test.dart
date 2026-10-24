import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:kreedum_construction/models/palette.dart';
import 'package:kreedum_construction/services/floor_document.dart';

/// Guards future additions: every SVG in assets/floors must parse and have
/// something to paint. Run with `flutter test`.
void main() {
  final svgs =
      Directory('assets/floors')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('found floor drawings', () => expect(svgs.length, greaterThanOrEqualTo(40)));

  for (final f in svgs) {
    test('parses ${f.path}', () {
      final doc = FloorDocument.parse(f.readAsStringSync());
      expect(doc.zones, isNotEmpty, reason: 'no paintable areas');
      if (f.path.contains('courts')) {
        expect(doc.hasNamedZones, isTrue, reason: 'courts should use class="zone_<name>"');
      }
      final rendered = doc.render({for (final z in doc.zones) z.index: const Color(0xFF2C62E0)});
      expect(rendered, contains('#2C62E0'));
      expect(doc.buildHitSvg(), isNot(contains('<image')));
    });
  }

  test('catalog only references existing files', () {
    final cat = jsonDecode(File('assets/floors/catalog.json').readAsStringSync()) as Map<String, dynamic>;
    for (final c in (cat['categories'] as List).cast<Map<String, dynamic>>()) {
      for (final i in (c['items'] as List).cast<Map<String, dynamic>>()) {
        expect(File(i['asset'] as String).existsSync(), isTrue, reason: i['asset'] as String);
      }
    }
  });

  test('colour parsing', () {
    expect(parseCssColor('pink'), const Color(0xFFFFC0CB));
    expect(parseCssColor('#0f0'), const Color(0xFF00FF00));
    expect(parseCssColor('url(#p)'), isNull);
    expect(colorHex(const Color(0xFF2C62E0)), '#2C62E0');
  });

  test('style blocks are inlined and shapes become areas', () {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<style>.st0{fill:pink;stroke:#000}</style>'
        '<path class="st0" d="M0 0H5V5Z"/><path class="st0" d="M0 0H5V5Z"/><rect class="st0" x="5" y="5" width="5" height="5"/></svg>';
    final doc = FloorDocument.parse(svg);
    expect(doc.zones.length, 2); // identical paths merge
    expect(doc.zones.first.original, const Color(0xFFFFC0CB));
  });
}
