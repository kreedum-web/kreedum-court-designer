import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';

import 'floor_document.dart';

/// Rasterised "which zone is where" map for tap-to-paint.
class HitMap {
  HitMap._(this._rgba, this.width, this.height, this._codeToZone, this.aspectRatio);

  final Uint8List _rgba;
  final int width;
  final int height;
  final Map<int, int> _codeToZone;

  /// Width / height of the drawing (matches what SvgPicture displays).
  final double aspectRatio;

  static Future<HitMap> build(FloorDocument doc, {double longSide = 1400}) async {
    final info = await vg.loadPicture(SvgStringLoader(doc.buildHitSvg()), null);
    try {
      final size = info.size;
      final scale = longSide / math.max(size.width, size.height);
      final w = math.max(1, (size.width * scale).round());
      final h = math.max(1, (size.height * scale).round());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale);
      canvas.drawPicture(info.picture);
      final image = await recorder.endRecording().toImage(w, h);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      final codes = <int, int>{for (final z in doc.zones) FloorDocument.hitCode(z.index): z.index};
      return HitMap._(bytes!.buffer.asUint8List(), w, h, codes, size.width / size.height);
    } finally {
      info.picture.dispose();
    }
  }

  /// Zone index at a point given as fractions (0..1) of the drawing's width/height.
  int? zoneAt(double fx, double fy) {
    final cx = (fx * width).floor();
    final cy = (fy * height).floor();
    // Exact pixel first, then widen the search a little so taps on
    // anti-aliased edges or thin lines still find the area underneath.
    for (var r = 0; r <= 6; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (r > 0 && dx.abs() != r && dy.abs() != r) continue;
          final z = _zoneAtPixel(cx + dx, cy + dy);
          if (z != null) return z;
        }
      }
    }
    return null;
  }

  int? _zoneAtPixel(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return null;
    final i = (y * width + x) * 4;
    if (_rgba[i + 3] != 255) return null;
    final code = (_rgba[i] << 16) | (_rgba[i + 1] << 8) | _rgba[i + 2];
    return _codeToZone[code];
  }
}
