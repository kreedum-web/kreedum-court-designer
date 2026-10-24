import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a client logo from the gallery and prepares it for the court boards.
class LogoService {
  LogoService._();

  static const defaultLogoAsset = 'assets/brand/logo_mark.png';

  /// Returns a square, transparent-padded PNG (so non-square logos are not
  /// stretched on the banner boards), or null if the user cancelled.
  static Future<Uint8List?> pickClientLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
    if (file == null) return null;
    return squarePng(await file.readAsBytes());
  }

  static Future<Uint8List> defaultLogo() async =>
      squarePng((await rootBundle.load(defaultLogoAsset)).buffer.asUint8List());

  static Future<Uint8List> squarePng(Uint8List bytes, {int size = 512, double padding = 0.06}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;

    final inner = size * (1 - padding * 2);
    final scale = inner / (src.width > src.height ? src.width : src.height);
    final w = src.width * scale;
    final h = src.height * scale;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH((size - w) / 2, (size - h) / 2, w, h),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final out = await recorder.endRecording().toImage(size, size);
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    src.dispose();
    out.dispose();
    return png!.buffer.asUint8List();
  }
}
