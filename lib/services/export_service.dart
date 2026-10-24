import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/palette.dart';

/// One line of the colour specification printed on the PDF / sent in enquiries.
class SpecLine {
  const SpecLine(this.area, this.color, {this.count = 1});
  final String area;
  final Color color;
  final int count;
}

/// Everything needed to export / share / enquire about one design.
class DesignSnapshot {
  DesignSnapshot({required this.title, required this.category, required this.png, required this.spec});

  final String title;
  final String category;
  final Uint8List png;
  final List<SpecLine> spec;

  String get fileStem {
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Kreedum_${slug}_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }

  /// Plain-text summary used for WhatsApp / e-mail / share text.
  String enquiryText() {
    final b = StringBuffer()
      ..writeln('Hi ${AppConfig.appName}, I would like a quote for this design:')
      ..writeln()
      ..writeln('• Design: $title ($category)');
    for (final s in spec) {
      final n = s.count > 1 ? ' – ${s.count} areas' : '';
      b.writeln('• ${s.area}: ${colorName(s.color)} ${colorHex(s.color)}$n');
    }
    b
      ..writeln()
      ..writeln('Site location: ')
      ..writeln('Approx. area (sq ft): ');
    return b.toString();
  }
}

class ExportService {
  ExportService._();

  /// Renders the widget behind [boundaryKey] (a RepaintBoundary) to PNG.
  static Future<Uint8List> capturePng(GlobalKey boundaryKey, {double longSide = 2400}) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final size = boundary.size;
    final ratio = longSide / math.max(size.width, size.height);
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<File> _temp(String name, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> shareImage(DesignSnapshot d, {Rect? origin}) async {
    final f = await _temp('${d.fileStem}.png', d.png);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'image/png')],
        subject: '${AppConfig.appName} – ${d.title}',
        text: d.enquiryText(),
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<void> sharePdf(DesignSnapshot d, {Rect? origin}) async {
    final f = await _temp('${d.fileStem}.pdf', await buildPdf(d));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'application/pdf')],
        subject: '${AppConfig.appName} – ${d.title}',
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<void> printPdf(DesignSnapshot d) async {
    final bytes = await buildPdf(d);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${d.fileStem}.pdf');
  }

  // ------------------------------------------------------------------ PDF

  static Future<pw.Font> _font(String asset) async => pw.Font.ttf(await rootBundle.load(asset));

  static Future<Uint8List> buildPdf(DesignSnapshot d) async {
    final body = await _font('assets/fonts/Inter_400Regular.ttf');
    final semi = await _font('assets/fonts/Inter_600SemiBold.ttf');
    final display = await _font('assets/fonts/SpaceGrotesk_700Bold.ttf');
    final mono = await _font('assets/fonts/IBMPlexMono_500Medium.ttf');
    final logo = pw.MemoryImage((await rootBundle.load('assets/brand/logo_mark_white.png')).buffer.asUint8List());
    final design = pw.MemoryImage(d.png);

    const navy = PdfColor.fromInt(0xFF0E1A3D);
    const blue = PdfColor.fromInt(0xFF2C62E0);
    const accent = PdfColor.fromInt(0xFF8FADFF);
    const slate = PdfColor.fromInt(0xFF4B5568);
    const slateLight = PdfColor.fromInt(0xFF8A93A6);
    const paper = PdfColor.fromInt(0xFFF6F8FC);
    const paperDim = PdfColor.fromInt(0xFFEEF1F8);

    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    pw.TextStyle t(pw.Font f, double s, PdfColor c, {double ls = 0}) =>
        pw.TextStyle(font: f, fontSize: s, color: c, letterSpacing: ls);

    final doc = pw.Document(
      title: '${AppConfig.appName} – ${d.title}',
      author: AppConfig.appName,
      theme: pw.ThemeData.withFont(base: body, bold: semi),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero),
        header: (ctx) => pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: 34, height: 34),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(AppConfig.brandWord, style: t(display, 18, PdfColors.white, ls: 1)),
                  pw.Text(AppConfig.brandSub, style: t(mono, 8, accent, ls: 2.5)),
                ],
              ),
              pw.Spacer(),
              pw.Text('DESIGN PROPOSAL', style: t(mono, 9, accent, ls: 2)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(color: paperDim, thickness: 1),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      [
                        AppConfig.phoneNumber,
                        AppConfig.email,
                        AppConfig.website.replaceFirst(RegExp(r'^https?://'), ''),
                      ].where((s) => s.isNotEmpty).join('   ·   '),
                      style: t(body, 8.5, slate),
                    ),
                  ),
                  pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: t(body, 8.5, slateLight)),
                ],
              ),
              if (AppConfig.address.isNotEmpty) pw.Text(AppConfig.address, style: t(body, 8, slateLight)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(d.category.toUpperCase(), style: t(mono, 9, blue, ls: 2)),
                pw.SizedBox(height: 4),
                pw.Text(d.title, style: t(display, 24, navy)),
                pw.SizedBox(height: 4),
                pw.Text('Prepared on $date', style: t(body, 9, slateLight)),
                pw.SizedBox(height: 16),
                pw.Container(
                  decoration: pw.BoxDecoration(color: paper, borderRadius: pw.BorderRadius.circular(10)),
                  padding: const pw.EdgeInsets.all(14),
                  alignment: pw.Alignment.center,
                  child: pw.Image(design, fit: pw.BoxFit.contain, height: 380),
                ),
                pw.SizedBox(height: 22),
                pw.Text('COLOUR SPECIFICATION', style: t(mono, 9, blue, ls: 2)),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: paperDim, width: 1)),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(3),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: paper),
                  children: ['', 'Area', 'Colour', 'Code']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                          child: pw.Text(h, style: t(semi, 9, navy)),
                        ),
                      )
                      .toList(),
                ),
                for (final s in d.spec)
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Container(
                          width: 14,
                          height: 14,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(s.color.toARGB32()),
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(color: paperDim),
                          ),
                        ),
                      ),
                      _cell(s.count > 1 ? '${s.area} (${s.count})' : s.area, t(body, 9.5, slate)),
                      _cell(colorName(s.color), t(body, 9.5, slate)),
                      _cell(colorHex(s.color), t(mono, 9, slate)),
                    ],
                  ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 14, 36, 0),
            child: pw.Text(
              'Colours shown on screen are indicative; final EPDM / acrylic shades may vary slightly. '
              'Contact us for physical samples and a detailed quotation.',
              style: t(body, 8.5, slateLight),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _cell(String s, pw.TextStyle st) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
    child: pw.Text(s, style: st),
  );
}
