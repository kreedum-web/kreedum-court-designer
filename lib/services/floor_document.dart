import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:xml/xml.dart';

import '../models/palette.dart';

/// One paintable area of a floor (may span several SVG shapes).
class FloorZone {
  FloorZone({
    required this.index,
    required this.key,
    required this.label,
    required this.elements,
    required this.original,
  });

  final int index;
  final String key;
  final String label;
  final List<XmlElement> elements;
  final Color original;

  /// True for areas detected automatically (one per shape, e.g. EPDM line-art)
  /// rather than named in the SVG (`class="zone_court"`).
  bool get isAuto => key.startsWith('area_');
}

/// Parsed, recolourable floor drawing.
///
/// Zone rules (in priority order) — see README "Adding a new floor":
///   1. shapes with `class="zone_<name>"` → named zone "<Name>" (shapes sharing a name paint together)
///   2. legacy classes `outer_id` / `inner_id` / `kitchen_id` / `<x>_id`
///   3. otherwise every filled shape becomes its own "Area N"
/// Logo slots: `<image class="logo_slot">` or `<image id="logo_id">`.
class FloorDocument {
  FloorDocument._(this._doc, this.zones, this.logoSlots);

  final XmlDocument _doc;
  final List<FloorZone> zones;
  final List<XmlElement> logoSlots;

  bool get hasLogoSlots => logoSlots.isNotEmpty;
  bool get hasNamedZones => zones.any((z) => !z.isAuto);

  static const _shapeTags = {'path', 'rect', 'circle', 'ellipse', 'polygon', 'polyline'};
  static const _nonRendered = {
    'defs',
    'clipPath',
    'mask',
    'pattern',
    'symbol',
    'marker',
    'linearGradient',
    'radialGradient',
  };
  static const _legacyLabels = {'outer_id': 'surround', 'inner_id': 'court', 'kitchen_id': 'kitchen'};
  static const zoneAttr = 'data-kz';

  factory FloorDocument.parse(String svg) {
    final doc = XmlDocument.parse(svg);
    final root = doc.rootElement;
    _inlineStyles(root);

    final shapes = root.descendantElements
        .where((e) => _shapeTags.contains(e.name.local) && !_insideNonRendered(e))
        .toList();

    // 1 + 2: named zones
    final named = <String, List<XmlElement>>{};
    for (final e in shapes) {
      for (final cls in (e.getAttribute('class') ?? '').split(RegExp(r'\s+'))) {
        String? key;
        if (cls.startsWith('zone_') && cls.length > 5) {
          key = cls.substring(5);
        } else if (cls.endsWith('_id') && cls.length > 3) {
          key = _legacyLabels[cls] ?? cls.substring(0, cls.length - 3);
        }
        if (key != null) {
          named.putIfAbsent(key, () => []).add(e);
          break;
        }
      }
    }

    final zones = <FloorZone>[];
    if (named.isNotEmpty) {
      named.forEach((key, els) {
        zones.add(
          FloorZone(
            index: zones.length,
            key: key,
            label: _humanize(key),
            elements: els,
            original: _effectiveFill(els.first) ?? const Color(0xFFCCCCCC),
          ),
        );
      });
    } else {
      // 3: one zone per filled shape — identical copies of a shape (common in
      // Illustrator exports) are merged so they always paint together.
      final byGeometry = <String, FloorZone>{};
      for (final e in shapes) {
        final fill = _effectiveFill(e);
        if (fill == null) continue;
        final geo = _geometryKey(e);
        final existing = byGeometry[geo];
        if (existing != null) {
          existing.elements.add(e);
          continue;
        }
        final n = zones.length + 1;
        final zone = FloorZone(index: zones.length, key: 'area_$n', label: 'Area $n', elements: [e], original: fill);
        zones.add(zone);
        byGeometry[geo] = zone;
      }
    }
    for (final z in zones) {
      for (final e in z.elements) {
        e.setAttribute(zoneAttr, '${z.index}');
      }
    }

    final logos = root.descendantElements
        .where(
          (e) =>
              e.name.local == 'image' &&
              ((e.getAttribute('class') ?? '').contains('logo_slot') || e.getAttribute('id') == 'logo_id'),
        )
        .toList();

    return FloorDocument._(doc, zones, logos);
  }

  // ---------------------------------------------------------------- painting

  /// Applies [colors] (zone index → colour) and returns the SVG to display.
  String render(Map<int, Color> colors) {
    for (final z in zones) {
      final c = colors[z.index] ?? z.original;
      for (final e in z.elements) {
        _setPaint(e, 'fill', colorHex(c));
      }
    }
    return _doc.toXmlString();
  }

  /// Replaces the picture in every logo slot with [png] (already square).
  void setLogo(Uint8List png) {
    final uri = 'data:image/png;base64,${base64Encode(png)}';
    for (final img in logoSlots) {
      var done = false;
      for (final attr in ['xlink:href', 'href']) {
        if (img.getAttribute(attr) != null) {
          img.setAttribute(attr, uri);
          done = true;
        }
      }
      if (!done) img.setAttribute('href', uri);
    }
  }

  // ---------------------------------------------------------------- hit map

  /// Colour code painted into the hidden hit-map for each zone.
  static int hitCode(int zoneIndex) {
    final c = ((zoneIndex + 1) * 2654435761) & 0xFFFFFF;
    return c == 0 ? 0x010101 : c;
  }

  /// A copy of the drawing where each zone is a flat, unique colour and
  /// everything else is invisible. Rasterised once to find which zone a tap hit.
  String buildHitSvg() {
    final copy = XmlDocument.parse(_doc.toXmlString());
    final root = copy.rootElement;
    final toRemove = <XmlElement>[];
    for (final e in root.descendantElements) {
      final tag = e.name.local;
      if (_insideNonRendered(e)) continue;
      if (const {'image', 'text', 'use', 'foreignObject'}.contains(tag)) {
        toRemove.add(e);
        continue;
      }
      for (final a in const ['opacity', 'fill-opacity', 'stroke-opacity', 'filter', 'mask', 'style']) {
        e.removeAttribute(a);
      }
      if (_shapeTags.contains(tag) || tag == 'line') {
        final z = int.tryParse(e.getAttribute(zoneAttr) ?? '');
        if (z != null) {
          e.setAttribute('fill', '#${hitCode(z).toRadixString(16).padLeft(6, '0')}');
        } else {
          e.setAttribute('fill', 'none');
        }
        e.setAttribute('stroke', 'none');
      }
    }
    for (final e in toRemove) {
      e.parent?.children.remove(e);
    }
    return copy.toXmlString();
  }

  // ---------------------------------------------------------------- helpers

  static const _geometryAttrs = ['d', 'points', 'x', 'y', 'width', 'height', 'cx', 'cy', 'r', 'rx', 'ry', 'transform'];

  static String _geometryKey(XmlElement e) {
    final b = StringBuffer(e.name.local)..write(identityHashCode(e.parent));
    for (final a in _geometryAttrs) {
      final v = e.getAttribute(a);
      if (v != null) b.write('|$a=${v.trim()}');
    }
    return b.toString();
  }

  static bool _insideNonRendered(XmlElement e) => e.ancestorElements.any((a) => _nonRendered.contains(a.name.local));

  static String _humanize(String key) =>
      key.split(RegExp(r'[_\-]+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  static String? _styleProp(XmlElement e, String prop) {
    final style = e.getAttribute('style');
    if (style == null) return null;
    for (final decl in style.split(';')) {
      final i = decl.indexOf(':');
      if (i > 0 && decl.substring(0, i).trim() == prop) return decl.substring(i + 1).trim();
    }
    return null;
  }

  static void _setPaint(XmlElement e, String prop, String value) {
    e.setAttribute(prop, value);
    final style = e.getAttribute('style');
    if (style != null && style.contains(prop)) {
      final kept = style
          .split(';')
          .where((d) => d.contains(':') && d.substring(0, d.indexOf(':')).trim() != prop)
          .join(';');
      if (kept.trim().isEmpty) {
        e.removeAttribute('style');
      } else {
        e.setAttribute('style', kept);
      }
    }
  }

  /// Fill actually used for [e] (own attribute/style, else inherited, else black).
  static Color? _effectiveFill(XmlElement e) {
    XmlElement? cur = e;
    while (cur != null) {
      final v = _styleProp(cur, 'fill') ?? cur.getAttribute('fill');
      if (v != null && v.trim() != 'inherit') {
        return parseCssColor(v); // null for none / url(...)
      }
      final p = cur.parent;
      cur = p is XmlElement ? p : null;
    }
    return const Color(0xFF000000);
  }

  /// Applies simple `.class { prop: value }` rules from `<style>` blocks as
  /// attributes so every renderer sees the same colours.
  static void _inlineStyles(XmlElement root) {
    final styles = root.descendantElements.where((e) => e.name.local == 'style').toList();
    if (styles.isEmpty) return;
    final rules = <String, Map<String, String>>{};
    final ruleRe = RegExp(r'([^{}]+)\{([^}]*)\}');
    for (final s in styles) {
      for (final m in ruleRe.allMatches(s.innerText)) {
        final props = <String, String>{};
        for (final decl in m.group(2)!.split(';')) {
          final i = decl.indexOf(':');
          if (i > 0) props[decl.substring(0, i).trim()] = decl.substring(i + 1).trim();
        }
        for (final sel in m.group(1)!.split(',')) {
          final t = sel.trim();
          if (RegExp(r'^\.[\w-]+$').hasMatch(t)) {
            rules.putIfAbsent(t.substring(1), () => {}).addAll(props);
          }
        }
      }
      s.parent?.children.remove(s);
    }
    if (rules.isEmpty) return;
    for (final e in root.descendantElements) {
      for (final cls in (e.getAttribute('class') ?? '').split(RegExp(r'\s+'))) {
        rules[cls]?.forEach((k, v) {
          if (k != 'enable-background' && e.getAttribute(k) == null && _styleProp(e, k) == null) {
            e.setAttribute(k, v);
          }
        });
      }
    }
  }
}
