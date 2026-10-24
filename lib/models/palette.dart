import 'package:flutter/material.dart';

class NamedColor {
  const NamedColor(this.name, this.color);
  final String name;
  final Color color;
}

/// Preset flooring shades shown in the editor palette.
/// Edit freely — the order here is the order in the app.
const List<NamedColor> kFloorPalette = [
  NamedColor('Kreedum Blue', Color(0xFF2C62E0)),
  NamedColor('Royal Blue', Color(0xFF1F49B8)),
  NamedColor('Navy', Color(0xFF0E1A3D)),
  NamedColor('Sky Blue', Color(0xFF6FA8DC)),
  NamedColor('Court Green', Color(0xFF1E6B45)),
  NamedColor('Grass Green', Color(0xFF3E8E4A)),
  NamedColor('Lime Green', Color(0xFF6FA34A)),
  NamedColor('Teal', Color(0xFF1B8A8A)),
  NamedColor('Terracotta', Color(0xFFB5452F)),
  NamedColor('Red', Color(0xFFD32F2F)),
  NamedColor('Orange', Color(0xFFE07B39)),
  NamedColor('Yellow', Color(0xFFF2C230)),
  NamedColor('Beige', Color(0xFFE6D3B3)),
  NamedColor('Maple', Color(0xFFD9A066)),
  NamedColor('Brown', Color(0xFF7A4B2A)),
  NamedColor('Pink', Color(0xFFF48FB1)),
  NamedColor('Purple', Color(0xFF7E57C2)),
  NamedColor('Light Grey', Color(0xFFC9CED8)),
  NamedColor('Grey', Color(0xFF8A93A6)),
  NamedColor('Charcoal', Color(0xFF3A3F4B)),
  NamedColor('Black', Color(0xFF111111)),
  NamedColor('White', Color(0xFFFFFFFF)),
];

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String colorName(Color c) {
  for (final n in kFloorPalette) {
    if (n.color.toARGB32() == c.toARGB32()) return n.name;
  }
  return 'Custom';
}

const Map<String, int> _cssNamed = {
  'black': 0x000000,
  'white': 0xFFFFFF,
  'red': 0xFF0000,
  'green': 0x008000,
  'lime': 0x00FF00,
  'blue': 0x0000FF,
  'yellow': 0xFFFF00,
  'cyan': 0x00FFFF,
  'aqua': 0x00FFFF,
  'magenta': 0xFF00FF,
  'fuchsia': 0xFF00FF,
  'pink': 0xFFC0CB,
  'brown': 0xA52A2A,
  'orange': 0xFFA500,
  'purple': 0x800080,
  'grey': 0x808080,
  'gray': 0x808080,
  'silver': 0xC0C0C0,
  'navy': 0x000080,
  'maroon': 0x800000,
  'olive': 0x808000,
  'teal': 0x008080,
  'gold': 0xFFD700,
  'beige': 0xF5F5DC,
  'tan': 0xD2B48C,
  'violet': 0xEE82EE,
  'indigo': 0x4B0082,
  'skyblue': 0x87CEEB,
  'darkgreen': 0x006400,
  'lightgreen': 0x90EE90,
  'lightblue': 0xADD8E6,
  'darkblue': 0x00008B,
  'darkred': 0x8B0000,
  'lightgrey': 0xD3D3D3,
  'lightgray': 0xD3D3D3,
  'darkgrey': 0xA9A9A9,
  'darkgray': 0xA9A9A9,
};

/// Parses SVG/CSS colour strings (#rgb, #rrggbb, rgb(), named). Returns null for
/// `none`, `url(...)`, `currentColor` or anything unknown.
Color? parseCssColor(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == 'none' || v == 'transparent' || v.startsWith('url(') || v == 'currentcolor') {
    return null;
  }
  if (v.startsWith('#')) {
    var h = v.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 8) h = h.substring(0, 6);
    final n = int.tryParse(h, radix: 16);
    return n == null || h.length != 6 ? null : Color(0xFF000000 | n);
  }
  final rgb = RegExp(r'rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)').firstMatch(v);
  if (rgb != null) {
    int ch(int i) => double.parse(rgb.group(i)!).round().clamp(0, 255);
    return Color.fromARGB(255, ch(1), ch(2), ch(3));
  }
  final named = _cssNamed[v];
  return named == null ? null : Color(0xFF000000 | named);
}
