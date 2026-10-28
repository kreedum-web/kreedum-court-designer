import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/theme.dart';
import '../models/catalog.dart';
import '../models/palette.dart';
import '../services/export_service.dart';
import '../services/floor_document.dart';
import '../services/floor_repository.dart';
import '../services/hit_map.dart';
import '../services/logo_service.dart';
import '../widgets/enquiry_sheet.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.item});
  final FloorItem item;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _boundaryKey = GlobalKey();
  final _transform = TransformationController();
  static const String _tutorialSeenKey = 'court_designer_tutorial_seen_v1';

  FloorDocument? _doc;
  HitMap? _hit;
  String? _svg;
  Object? _error;

  Map<int, Color> _colors = {};
  late Map<int, Color> _initial;
  final List<Map<int, Color>> _undo = [];
  Color _active = kFloorPalette.first.color;
  final List<Color> _recentCustom = [];

  // Logo overlay for designs without built-in logo boards (e.g. EPDM floors).
  Uint8List? _overlayLogo;
  Offset _logoPos = const Offset(0.5, 0.5);
  double _logoSize = 0.22;
  bool _moveLogo = false;
  bool _slotLogoHidden = false;

  bool _busy = false;
  DesignSnapshot? _snapshotCache;

  static final Uint8List _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _maybeShowFirstRunTutorial() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_tutorialSeenKey) ?? false) return;
    if (!mounted) return;

    await _showHelp(firstRun: true);

    await prefs.setBool(_tutorialSeenKey, true);
  }

  Future<void> _load() async {
    try {
      final doc = await FloorRepository.open(widget.item);
      _initial = FloorRepository.initialColors(doc, widget.item);
      final hit = await HitMap.build(doc);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _hit = hit;
        _colors = Map.of(_initial);
        _svg = doc.render(_colors);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowFirstRunTutorial();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // ------------------------------------------------------------- painting

  void _commit(Map<int, Color> next) {
    _undo.add(Map.of(_colors));
    if (_undo.length > 60) _undo.removeAt(0);
    setState(() {
      _colors = next;
      _svg = _doc!.render(_colors);
      _snapshotCache = null;
    });
  }

  void _paintZone(int zone) {
    if (_colors[zone] == _active) return;
    HapticFeedback.selectionClick();
    _commit({..._colors, zone: _active});
  }

  void _onCanvasTap(Offset local, Size size) {
    if (_moveLogo) {
      _placeLogo(local, size);
      return;
    }
    final zone = _hit?.zoneAt(local.dx / size.width, local.dy / size.height);
    if (zone != null) _paintZone(zone);
  }

  void _placeLogo(Offset local, Size size) => setState(() {
        _logoPos = Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));
        _snapshotCache = null;
      });

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _colors = _undo.removeLast();
      _svg = _doc!.render(_colors);
      _snapshotCache = null;
    });
  }

  void _reset() => _commit(Map.of(_initial));

  void _fillAll() => _commit({for (final z in _doc!.zones) z.index: _active});

  Future<void> _pickCustomColor() async {
    var picked = _active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom colour'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _active,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use colour')),
        ],
      ),
    );
    if (ok == true) {
      final c = picked.withValues(alpha: 1);
      setState(() {
        _active = c;
        _recentCustom.removeWhere((x) => x.toARGB32() == c.toARGB32());
        _recentCustom.insert(0, c);
        if (_recentCustom.length > 6) _recentCustom.removeLast();
      });
    }
  }

  // ------------------------------------------------------------- logo

  Future<void> _applyLogo(Uint8List png) async {
    final doc = _doc!;
    setState(() {
      if (doc.hasLogoSlots) {
        doc.setLogo(png);
        _slotLogoHidden = false;
        _svg = doc.render(_colors);
      } else {
        _overlayLogo = png;
        _moveLogo = true;
      }
      _snapshotCache = null;
    });
  }

  void _removeLogo() {
    final doc = _doc!;
    setState(() {
      if (doc.hasLogoSlots) {
        doc.setLogo(_transparentPng);
        _slotLogoHidden = true;
        _svg = doc.render(_colors);
      } else {
        _overlayLogo = null;
        _moveLogo = false;
      }
      _snapshotCache = null;
    });
  }

  Future<void> _logoSheet() async {
    final doc = _doc;
    if (doc == null) return;
    final hasLogo = doc.hasLogoSlots ? !_slotLogoHidden : _overlayLogo != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text(
                  doc.hasLogoSlots ? 'Logo on the court boards' : 'Logo on the floor',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined, color: KColors.blue),
                title: const Text("Upload client's logo"),
                subtitle: const Text('PNG with a transparent background looks best'),
                onTap: () => Navigator.pop(ctx, 'upload'),
              ),
              ListTile(
                leading: Image.asset('assets/brand/logo_mark.png', width: 24, height: 24),
                title: const Text('Use Kreedum logo'),
                onTap: () => Navigator.pop(ctx, 'kreedum'),
              ),
              if (!doc.hasLogoSlots && _overlayLogo != null)
                ListTile(
                  leading: const Icon(Icons.open_with_rounded, color: KColors.blue),
                  title: const Text('Move / resize logo'),
                  onTap: () => Navigator.pop(ctx, 'move'),
                ),
              if (hasLogo)
                ListTile(
                  leading: const Icon(Icons.hide_image_outlined, color: KColors.slate),
                  title: const Text('Remove logo'),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'upload':
          final png = await LogoService.pickClientLogo();
          if (png != null) await _applyLogo(png);
        case 'kreedum':
          await _applyLogo(await LogoService.defaultLogo());
        case 'move':
          setState(() => _moveLogo = true);
        case 'remove':
          _removeLogo();
      }
    } catch (e) {
      _toast('Could not load that image ($e)');
    }
  }

  // ------------------------------------------------------------- export

  Future<DesignSnapshot> _snapshot() async {
    if (_snapshotCache != null) return _snapshotCache!;
    final wasMoving = _moveLogo;
    if (wasMoving) {
      setState(() => _moveLogo = false); // hide the dashed handle
      await WidgetsBinding.instance.endOfFrame;
    }
    final png = await ExportService.capturePng(_boundaryKey);
    if (wasMoving && mounted) setState(() => _moveLogo = true);

    final doc = _doc!;
    final List<SpecLine> spec;
    if (doc.hasNamedZones) {
      spec = [for (final z in doc.zones) SpecLine(z.label, _colors[z.index] ?? z.original)];
    } else {
      final counts = <int, int>{};
      for (final z in doc.zones) {
        final c = (_colors[z.index] ?? z.original).toARGB32();
        counts[c] = (counts[c] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      spec = [
        for (var i = 0; i < sorted.length; i++)
          SpecLine(i == 0 ? 'Main colour' : 'Accent colour $i', Color(sorted[i].key)),
      ];
    }
    return _snapshotCache = DesignSnapshot(
      title: widget.item.title,
      category: widget.item.category.title,
      png: png,
      spec: spec,
    );
  }

  Future<void> _guard(Future<void> Function() job) async {
    if (_busy || _doc == null) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _toast('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text('Export design', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: KColors.blue),
                title: const Text('Image (PNG)'),
                subtitle: const Text('Save to gallery or send on any app'),
                onTap: () => Navigator.pop(ctx, 'png'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: KColors.blue),
                title: const Text('PDF proposal'),
                subtitle: const Text('Branded page with colour specification'),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: KColors.blue),
                title: const Text('Print'),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'png':
        await _guard(() async => ExportService.shareImage(await _snapshot()));
      case 'pdf':
        await _guard(() async => ExportService.sharePdf(await _snapshot()));
      case 'print':
        await _guard(() async => ExportService.printPdf(await _snapshot()));
    }
  }

  // ------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _undo.isEmpty ? null : _undoLast,
            icon: const Icon(Icons.undo_rounded),
            color: KColors.navy,
            disabledColor: KColors.slateLight.withValues(alpha: 0.5),
          ),
          IconButton(
            tooltip: 'Get a quote',
            onPressed: doc == null || _busy ? null : () => showEnquirySheet(context, snapshot: _snapshot),
            icon: const Icon(Icons.support_agent_rounded, size: 26),
            color: KColors.blue,
          ),
          PopupMenuButton<String>(
            iconColor: KColors.navy,
            enabled: doc != null,
            onSelected: (v) {
              if (v == 'reset') _reset();
              if (v == 'fill') _fillAll();
              if (v == 'help') _showHelp();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fill', child: Text('Fill whole floor with selected colour')),
              PopupMenuItem(value: 'reset', child: Text('Reset colours')),
              PopupMenuItem(value: 'help', child: Text('How to use')),
            ],
          ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, color: KColors.blue),
              )
            : null,
      ),
      body: _error != null
          ? Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not open design.\n$_error')),
            )
          : doc == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _canvas()),
                    if (_moveLogo) _logoControls() else ...[if (doc.hasNamedZones) _zoneStrip(doc), _palette()],
                    _actionBar(),
                  ],
                ),
    );
  }

  Widget _canvas() {
    final hit = _hit!;
    return Container(
      color: KColors.paper,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              panEnabled: !_moveLogo,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: hit.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = box.biggest;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _onCanvasTap(d.localPosition, size),
                          onPanStart: _moveLogo ? (d) => _placeLogo(d.localPosition, size) : null,
                          onPanUpdate: _moveLogo ? (d) => _placeLogo(d.localPosition, size) : null,
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: ColoredBox(
                              color: KColors.white,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  SvgPicture.string(_svg!, fit: BoxFit.fill),
                                  if (_overlayLogo != null) _overlay(size),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: _Hint(text: _moveLogo ? 'Drag on the floor to place the logo' : 'Pick a colour, then tap an area'),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filledTonal(
              tooltip: 'Fit to screen',
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay(Size size) {
    final s = size.width * _logoSize;
    return Positioned(
      left: _logoPos.dx * size.width - s / 2,
      top: _logoPos.dy * size.height - s / 2,
      width: s,
      height: s,
      child: IgnorePointer(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: _moveLogo ? Border.all(color: KColors.blue, width: 1.5) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Image.memory(_overlayLogo!, fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
    );
  }

  Widget _logoControls() {
    return Container(
      color: KColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.photo_size_select_large_rounded, color: KColors.slate, size: 20),
          Expanded(
            child: Slider(
              min: 0.08,
              max: 0.8,
              value: _logoSize,
              onChanged: (v) => setState(() {
                _logoSize = v;
                _snapshotCache = null;
              }),
            ),
          ),
          FilledButton(
            onPressed: () => setState(() {
              _moveLogo = false;
              _snapshotCache = null;
            }),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _zoneStrip(FloorDocument doc) {
    return Container(
      color: KColors.white,
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: doc.zones.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final z = doc.zones[i];
            final c = _colors[z.index] ?? z.original;
            return ActionChip(
              tooltip: 'Paint ${z.label} with the selected colour',
              avatar: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: KColors.paperDim),
                ),
              ),
              label: Text(z.label),
              labelStyle: Theme.of(context).textTheme.labelMedium,
              backgroundColor: KColors.paper,
              side: const BorderSide(color: KColors.paperDim),
              onPressed: () => _paintZone(z.index),
            );
          },
        ),
      ),
    );
  }

  Widget _palette() {
    final swatches = <(Color, String)>[
      for (final c in _recentCustom) (c, 'Custom ${colorHex(c)}'),
      for (final n in kFloorPalette) (n.color, n.name),
    ];
    return Container(
      color: KColors.white,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('COLOUR', style: KText.eyebrow(color: KColors.slateLight)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${colorName(_active)} · ${colorHex(_active)}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: swatches.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _SwatchButton(
                    tooltip: 'Custom colour',
                    selected: false,
                    onTap: _pickCustomColor,
                    child: const Icon(Icons.colorize_rounded, size: 20, color: KColors.blue),
                  );
                }
                final (c, name) = swatches[i - 1];
                return _SwatchButton(
                  tooltip: name,
                  color: c,
                  selected: c.toARGB32() == _active.toARGB32(),
                  onTap: () => setState(() => _active = c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: KColors.white,
        border: Border(top: BorderSide(color: KColors.paperDim)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              _BarButton(icon: Icons.add_photo_alternate_outlined, label: 'Logo', onTap: _logoSheet),
              _BarButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () => _guard(() async => ExportService.shareImage(await _snapshot())),
              ),
              _BarButton(icon: Icons.picture_as_pdf_outlined, label: 'Export', onTap: _exportSheet),
              _BarButton(
                icon: Icons.print_outlined,
                label: 'Print',
                onTap: () => _guard(() async => ExportService.printPdf(await _snapshot())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHelp({bool firstRun = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstRun ? 'Welcome to Kreedum Court Designer' : 'How to use',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                firstRun
                    ? 'Design your court by choosing colours, '
                        'painting individual areas and adding logos.'
                    : 'Follow these steps to create your design.',
              ),
              const SizedBox(height: 20),
              const _TutorialStep(
                icon: Icons.palette_outlined,
                title: '1. Choose a colour',
                detail: 'Select a preset shade below or use the custom colour picker.',
              ),
              const _TutorialStep(
                icon: Icons.touch_app_outlined,
                title: '2. Colour the court',
                detail: 'Tap an area to paint it. Pinch to zoom for smaller areas.',
              ),
              const _TutorialStep(
                icon: Icons.image_outlined,
                title: '3. Add a logo',
                detail: 'Use Logo to upload a client logo or place the Kreedum logo.',
              ),
              const _TutorialStep(
                icon: Icons.ios_share_outlined,
                title: '4. Export or get a quote',
                detail: 'Share an image, export a PDF, print your design or request a quote.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    firstRun ? 'Start designing' : 'Got it',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: KColors.blue, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: KColors.navyA(0.78), borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: const TextStyle(color: KColors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({required this.tooltip, required this.selected, required this.onTap, this.color, this.child});

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          padding: EdgeInsets.all(selected ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? KColors.blue : KColors.paperDim, width: selected ? 2.5 : 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(color: color ?? KColors.tint, shape: BoxShape.circle),
            child: child == null ? null : Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: KColors.navy, size: 22),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
