import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

enum _EditMode { move, highlight, draw, erase, redact }

class PdfEditorScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  const PdfEditorScreen({
    super.key,
    required this.pdfPath,
    this.title = 'PDF Editor',
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final _renderService = PdfRenderService();
  final _toolsService = PdfToolsService();

  int _pageCount = 0;
  int _pageIndex = 0;
  RenderedPage? _page;
  bool _loading = true;
  bool _saving = false;

  final List<PdfOverlay> _overlays = [];
  PdfOverlay? _selected;

  _EditMode _mode = _EditMode.move;
  Color _color = const Color(0xFFFFEB3B); // highlight yellow
  Color _inkColor = const Color(0xFFE53935); // ink red
  double _strokeWidth = 4.0;

  // Real-time live gesture tracking state
  Offset? _currentTouchLocal;
  Offset? _dragStart;
  Rect? _draftRect;
  List<Offset> _draftPoints = [];

  // Scale gesture state for pinch-to-resize overlays.
  double _scaleStart = 1.0;
  Rect? _scaleStartRect;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _pageCount = await _toolsService.pageCount(widget.pdfPath);
      await _loadPage(0);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to open PDF: $e');
      }
    }
  }

  Future<void> _loadPage(int index) async {
    setState(() => _loading = true);
    try {
      final rendered = await _renderService.renderPage(widget.pdfPath, index);
      if (!mounted) return;
      setState(() {
        _pageIndex = index;
        _page = rendered;
        _loading = false;
        _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to render page: $e');
    }
  }

  List<PdfOverlay> get _pageOverlays =>
      _overlays.where((o) => o.pageIndex == _pageIndex).toList();

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selected != null)
            Semantics(
              label: 'Delete selected element',
              button: true,
              child: IconButton(
                tooltip: 'Delete element',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _overlays.remove(_selected);
                    _selected = null;
                  });
                },
              ),
            ),
          IconButton(
            tooltip: 'Save',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, color: Color(0xFF00E5FF)),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCanvas()),
          if (_mode == _EditMode.draw) _buildStrokeControl(),
          if (_selected != null && _selected!.type != PdfOverlayType.ink)
            _buildSizeControl(),
          _buildPager(),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_page == null) {
      return const Center(child: Text('Could not render page.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final ar = _page!.aspectRatio;
        var w = constraints.maxWidth;
        var h = w / ar;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * ar;
        }
        final size = Size(w, h);

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                if (_mode == _EditMode.move) {
                  setState(() => _selected = null);
                } else if (_mode == _EditMode.erase) {
                  final n = _toNorm(d.localPosition, size);
                  setState(() => _eraseAt(n));
                }
              },
              onPanStart: _mode == _EditMode.move
                  ? null
                  : (d) {
                      final n = _toNorm(d.localPosition, size);
                      setState(() {
                        _currentTouchLocal = d.localPosition;
                        _dragStart = n;
                        if (_mode == _EditMode.draw) {
                          _draftPoints = [n];
                        } else if (_mode == _EditMode.erase) {
                          _eraseAt(n);
                        } else {
                          _draftRect = Rect.fromLTRB(n.dx, n.dy, n.dx, n.dy);
                        }
                      });
                    },
              onPanUpdate: _mode == _EditMode.move
                  ? null
                  : (d) {
                      final n = _toNorm(d.localPosition, size);
                      setState(() {
                        _currentTouchLocal = d.localPosition;
                        if (_mode == _EditMode.draw) {
                          _draftPoints = [..._draftPoints, n];
                        } else if (_mode == _EditMode.erase) {
                          _eraseAt(n);
                        } else if (_dragStart != null) {
                          final minX = _dragStart!.dx < n.dx ? _dragStart!.dx : n.dx;
                          final maxX = _dragStart!.dx > n.dx ? _dragStart!.dx : n.dx;
                          final minY = _dragStart!.dy < n.dy ? _dragStart!.dy : n.dy;
                          final maxY = _dragStart!.dy > n.dy ? _dragStart!.dy : n.dy;
                          _draftRect = Rect.fromLTRB(minX, minY, maxX, maxY);
                        }
                      });
                    },
              onPanEnd: _mode == _EditMode.move
                  ? null
                  : (_) {
                      setState(() => _currentTouchLocal = null);
                      _commitDraft();
                    },
              onPanCancel: () {
                setState(() {
                  _currentTouchLocal = null;
                  _draftRect = null;
                  _draftPoints = [];
                });
              },
              child: RepaintBoundary(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // PDF Rendered Background Page
                    Positioned.fill(
                      child: Image.memory(
                        _page!.bytes,
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('Page render failed')),
                      ),
                    ),

                    // Existing Committed Overlays
                    ..._pageOverlays.map((o) => _buildOverlayWidget(o, size)),

                    // Real-Time Live Drag Rectangle (Highlight / Redact)
                    if (_draftRect != null && _mode != _EditMode.move && _mode != _EditMode.draw && _mode != _EditMode.erase)
                      Positioned(
                        left: _draftRect!.left * w,
                        top: _draftRect!.top * h,
                        width: (_draftRect!.width * w).clamp(2.0, w),
                        height: (_draftRect!.height * h).clamp(2.0, h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _mode == _EditMode.redact
                                ? Colors.black.withValues(alpha: 0.85)
                                : _color.withValues(alpha: 0.40),
                            border: Border.all(
                              color: _mode == _EditMode.redact
                                  ? Colors.redAccent
                                  : _color,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                    // Real-Time Live Ink Painting
                    if (_draftPoints.length > 1)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _InkPainter(
                            _draftPoints,
                            _inkColor,
                            size,
                            strokeWidth: _strokeWidth,
                          ),
                        ),
                      ),

                    // Real-Time Live Finger Touch Pointer Indicator
                    if (_currentTouchLocal != null && _mode != _EditMode.move)
                      Positioned(
                        left: _currentTouchLocal!.dx - 14,
                        top: _currentTouchLocal!.dy - 14,
                        child: IgnorePointer(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _mode == _EditMode.erase
                                  ? Colors.red.withValues(alpha: 0.40)
                                  : (_mode == _EditMode.draw ? _inkColor : _color)
                                      .withValues(alpha: 0.35),
                              border: Border.all(
                                color: _mode == _EditMode.erase
                                    ? Colors.redAccent
                                    : Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _eraseAt(Offset normPoint) {
    const targetRadius = 0.06;
    _overlays.removeWhere((o) {
      if (o.pageIndex != _pageIndex) return false;
      return o.rect.inflate(targetRadius).contains(normPoint);
    });
  }

  Widget _buildOverlayWidget(PdfOverlay o, Size size) {
    final left = o.rect.left * size.width;
    final top = o.rect.top * size.height;
    final width = (o.rect.width * size.width).clamp(4.0, size.width);
    final height = (o.rect.height * size.height).clamp(4.0, size.height);
    final isSelected = identical(o, _selected);

    Widget content;
    switch (o.type) {
      case PdfOverlayType.text:
        content = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            o.text,
            style: TextStyle(
              color: o.color,
              fontSize: o.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      case PdfOverlayType.image:
        content = Image.memory(
          o.imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(color: Colors.grey.shade300),
        );
        break;
      case PdfOverlayType.highlight:
        content = Container(color: o.color.withValues(alpha: 0.40));
        break;
      case PdfOverlayType.underline:
        content = Align(
          alignment: Alignment.bottomLeft,
          child: Container(height: 3, width: width, color: o.color),
        );
        break;
      case PdfOverlayType.ink:
        content = CustomPaint(
          painter: _InkPainter(
            o.points
                .map((p) => Offset(
                      (p.dx - o.rect.left) /
                          (o.rect.width == 0 ? 1 : o.rect.width),
                      (p.dy - o.rect.top) /
                          (o.rect.height == 0 ? 1 : o.rect.height),
                    ))
                .toList(),
            o.color,
            Size(width, height),
            strokeWidth: o.strokeWidth,
          ),
        );
        break;
      case PdfOverlayType.redact:
        content = Container(color: o.color);
        break;
      case PdfOverlayType.ocrText:
        content = Container(
          decoration: BoxDecoration(
            color: Colors.yellow.withValues(alpha: 0.35),
            border: Border.all(color: Colors.orange, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(3),
          child: Text(
            o.text,
            style: TextStyle(
              color: Colors.black87,
              fontSize: (o.fontSize * 0.85).clamp(9, 26),
              fontWeight: FontWeight.w500,
            ),
            maxLines: null,
          ),
        );
        break;
    }

    final movable = o.type != PdfOverlayType.ink;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = o);
          if (o.type == PdfOverlayType.ocrText) {
            _editOcrText(o);
          }
        },
        onScaleStart: !movable
            ? null
            : (details) {
                setState(() => _selected = o);
                _scaleStart = 1.0;
                _scaleStartRect = o.rect;
              },
        onScaleUpdate: !movable
            ? null
            : (details) {
                setState(() {
                  _selected = o;
                  if (_scaleStartRect == null) return;
                  final r = _scaleStartRect!;
                  if (details.scale == 1.0) {
                    final dx = details.focalPointDelta.dx / size.width;
                    final dy = details.focalPointDelta.dy / size.height;
                    o.rect = r.translate(dx, dy);
                    _scaleStartRect = o.rect;
                  } else {
                    final factor = details.scale / _scaleStart;
                    final newW = (r.width * factor).clamp(0.04, 0.96);
                    final newH = (r.height * factor).clamp(0.04, 0.96);
                    o.rect = Rect.fromLTWH(
                      r.left + (r.width - newW) / 2,
                      r.top + (r.height - newH) / 2,
                      newW,
                      newH,
                    );
                  }
                });
              },
        onScaleEnd: !movable
            ? null
            : (_) {
                _scaleStartRect = null;
              },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: const Color(0xFF00E5FF), width: 2)
                : null,
            borderRadius: BorderRadius.circular(isSelected ? 4 : 0),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildStrokeControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.90),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.line_weight, size: 18),
          const SizedBox(width: 8),
          const Text('Stroke Weight', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Slider(
              value: _strokeWidth,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              label: '${_strokeWidth.round()} px',
              onChanged: (v) => setState(() => _strokeWidth = v),
            ),
          ),
          Container(
            width: _strokeWidth.clamp(4, 20),
            height: _strokeWidth.clamp(4, 20),
            decoration: BoxDecoration(
              color: _inkColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPager() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? const Color(0xFF161622).withValues(alpha: 0.80)
        : Colors.white.withValues(alpha: 0.85);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: glassColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _pageIndex > 0 ? () => _loadPage(_pageIndex - 1) : null,
              ),
              Text(
                'Page ${_pageIndex + 1} / $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _pageIndex < _pageCount - 1
                    ? () => _loadPage(_pageIndex + 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeControl() {
    final o = _selected!;
    final currentWidth = (o.rect.width * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.90),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.aspect_ratio, size: 18),
              const SizedBox(width: 8),
              const Text('Size', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text('$currentWidth %', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: currentWidth.toDouble().clamp(5, 150),
            min: 5,
            max: 150,
            onChanged: (v) {
              setState(() {
                final factor = v / 100;
                final newW = factor.clamp(0.05, 0.95);
                final newH = (o.rect.height / o.rect.width * newW).clamp(0.05, 0.95);
                o.rect = Rect.fromLTWH(
                  o.rect.left + (o.rect.width - newW) / 2,
                  o.rect.top + (o.rect.height - newH) / 2,
                  newW,
                  newH,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? const Color(0xFF14141F).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.92);

    return SafeArea(
      top: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _toolButton(Icons.text_fields, 'Text', _mode == _EditMode.move, _addText),
                  _toolButton(Icons.draw, 'Sign', false, _addSignature),
                  _toolButton(Icons.approval, 'Stamp', false, _addStamp),
                  _toolButton(
                    Icons.highlight,
                    'Highlight',
                    _mode == _EditMode.highlight,
                    () => setState(() => _mode = _mode == _EditMode.highlight ? _EditMode.move : _EditMode.highlight),
                  ),
                  _toolButton(
                    Icons.gesture,
                    'Draw',
                    _mode == _EditMode.draw,
                    () => setState(() => _mode = _mode == _EditMode.draw ? _EditMode.move : _EditMode.draw),
                  ),
                  _toolButton(
                    Icons.auto_fix_normal,
                    'Erase',
                    _mode == _EditMode.erase,
                    () => setState(() => _mode = _mode == _EditMode.erase ? _EditMode.move : _EditMode.erase),
                  ),
                  _toolButton(
                    Icons.security,
                    'Redact',
                    _mode == _EditMode.redact,
                    () => setState(() => _mode = _mode == _EditMode.redact ? _EditMode.move : _EditMode.redact),
                  ),
                  _toolButton(Icons.text_snippet, 'OCR', false, _runOcr),
                  _toolButton(Icons.palette, 'Color', false, _pickColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, bool active, VoidCallback onTap) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Semantics(
      label: '$label tool',
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _toNorm(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  void _commitDraft() {
    if (_mode == _EditMode.highlight && _draftRect != null) {
      if (_draftRect!.width > 0.005 && _draftRect!.height > 0.005) {
        _overlays.add(PdfOverlay(
          type: PdfOverlayType.highlight,
          pageIndex: _pageIndex,
          rect: _draftRect!,
          color: _color,
        ));
      }
    } else if (_mode == _EditMode.draw && _draftPoints.length > 1) {
      double minX = 1, minY = 1, maxX = 0, maxY = 0;
      for (final p in _draftPoints) {
        minX = p.dx < minX ? p.dx : minX;
        minY = p.dy < minY ? p.dy : minY;
        maxX = p.dx > maxX ? p.dx : maxX;
        maxY = p.dy > maxY ? p.dy : maxY;
      }
      _overlays.add(PdfOverlay(
        type: PdfOverlayType.ink,
        pageIndex: _pageIndex,
        rect: Rect.fromLTRB(minX, minY, maxX, maxY),
        points: List.of(_draftPoints),
        color: _inkColor,
        strokeWidth: _strokeWidth,
      ));
    } else if (_mode == _EditMode.redact && _draftRect != null) {
      if (_draftRect!.width > 0.005 && _draftRect!.height > 0.005) {
        _overlays.add(PdfOverlay(
          type: PdfOverlayType.redact,
          pageIndex: _pageIndex,
          rect: _draftRect!,
          color: Colors.black,
        ));
      }
    }
    setState(() {
      _draftRect = null;
      _draftPoints = [];
      _dragStart = null;
    });
  }

  Future<void> _runOcr() async {
    if (_page == null) return;
    setState(() => _loading = true);
    try {
      final tempDir = await Directory.systemTemp.createTemp('ocr_');
      final tempFile = File('${tempDir.path}/page.png');
      await tempFile.writeAsBytes(_page!.bytes);

      final ocr = OcrService();
      try {
        final result = await ocr.extractStructured(tempFile.path);
        if (result.lines.isEmpty) {
          _snack('No text recognized on this page');
          return;
        }

        final scaleX = 1.0 / result.imageWidth;
        final scaleY = 1.0 / result.imageHeight;

        setState(() {
          for (final line in result.lines) {
            if (line.text.trim().isEmpty) continue;
            final box = line.box;
            _overlays.add(PdfOverlay(
              type: PdfOverlayType.ocrText,
              pageIndex: _pageIndex,
              rect: Rect.fromLTWH(
                box.left * scaleX,
                box.top * scaleY,
                box.width * scaleX,
                box.height * scaleY,
              ),
              text: line.text.trim(),
              fontSize: 14,
            ));
          }
          _selected = null;
        });
        _snack('Added ${result.lines.length} text blocks. Tap to edit.');
      } finally {
        ocr.dispose();
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      _snack('OCR failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editOcrText(PdfOverlay o) async {
    final controller = TextEditingController(text: o.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Recognized Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Correct text...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      setState(() => o.text = text);
    }
    controller.dispose();
  }

  Future<void> _addText() async {
    setState(() => _mode = _EditMode.move);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Type text...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      final o = PdfOverlay(
        type: PdfOverlayType.text,
        pageIndex: _pageIndex,
        rect: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.06),
        text: text.trim(),
        color: _inkColor,
        fontSize: 18,
      );
      _overlays.add(o);
      _selected = o;
    });
  }

  Future<void> _addSignature() async {
    setState(() => _mode = _EditMode.move);
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SignatureLibrarySheet(),
    );
    if (bytes == null) return;
    setState(() {
      final o = PdfOverlay(
        type: PdfOverlayType.image,
        pageIndex: _pageIndex,
        rect: const Rect.fromLTWH(0.25, 0.6, 0.4, 0.15),
        imageBytes: bytes,
      );
      _overlays.add(o);
      _selected = o;
    });
  }

  Future<void> _addStamp() async {
    setState(() => _mode = _EditMode.move);
    const stamps = <(String, Color)>[
      ('APPROVED', Color(0xFF2E7D32)),
      ('PAID', Color(0xFF2E7D32)),
      ('CONFIDENTIAL', Color(0xFFC62828)),
      ('DRAFT', Color(0xFF616161)),
      ('URGENT', Color(0xFFC62828)),
      ('REJECTED', Color(0xFFC62828)),
      ('REVIEWED', Color(0xFF1565C0)),
      ('COPY', Color(0xFF616161)),
    ];
    final picked = await showModalBottomSheet<(String, Color)>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a stamp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stamps
                  .map((s) => GestureDetector(
                        onTap: () => Navigator.pop(context, s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: s.$2, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.$1,
                            style: TextStyle(
                              color: s.$2,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      final o = PdfOverlay(
        type: PdfOverlayType.text,
        pageIndex: _pageIndex,
        rect: const Rect.fromLTWH(0.25, 0.3, 0.4, 0.08),
        text: picked.$1,
        color: picked.$2,
        fontSize: 28,
      );
      _overlays.add(o);
      _selected = o;
    });
  }

  Future<void> _pickColor() async {
    const palette = [
      Color(0xFFFFEB3B), // Yellow
      Color(0xFF00E5FF), // Cyan
      Color(0xFF00E676), // Green
      Color(0xFFFF4081), // Pink
      Color(0xFFFF9100), // Orange
      Color(0xFFE53935), // Red
      Color(0xFF8A2BE2), // Purple
      Color(0xFF000000), // Black
      Color(0xFFFFFFFF), // White
    ];
    final picked = await showModalBottomSheet<Color>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: palette
              .map((c) => GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1.5),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (_mode == _EditMode.draw) {
        _inkColor = picked;
      } else {
        _color = picked;
      }
      if (_selected != null) _selected!.color = picked;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final outPath = await _toolsService.applyOverlays(
        widget.pdfPath,
        _overlays,
        title: 'Edited',
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _showResult(outPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Save failed: $e');
    }
  }

  void _showResult(String path) {
    showPdfResult(context, path);
  }
}

class _InkPainter extends CustomPainter {
  final List<Offset> normPoints;
  final Color color;
  final Size logical;
  final double strokeWidth;

  _InkPainter(this.normPoints, this.color, this.logical, {this.strokeWidth = 4.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (normPoints.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (normPoints.length == 1) {
      canvas.drawCircle(
        Offset(normPoints[0].dx * size.width, normPoints[0].dy * size.height),
        strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(normPoints[0].dx * size.width, normPoints[0].dy * size.height);
    for (var i = 1; i < normPoints.length; i++) {
      final p0 = Offset(normPoints[i - 1].dx * size.width, normPoints[i - 1].dy * size.height);
      final p1 = Offset(normPoints[i].dx * size.width, normPoints[i].dy * size.height);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) =>
      old.normPoints != normPoints || old.color != color || old.strokeWidth != strokeWidth;
}

class _SignatureLibrarySheet extends StatefulWidget {
  const _SignatureLibrarySheet();

  @override
  State<_SignatureLibrarySheet> createState() => _SignatureLibrarySheetState();
}

class _SignatureLibrarySheetState extends State<_SignatureLibrarySheet> {
  List<String> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await AppStorage.listSignatures();
    if (mounted) {
      setState(() {
        _saved = saved;
        _loading = false;
      });
    }
  }

  Future<void> _drawNew() async {
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SignaturePad(),
    );
    if (bytes == null || !mounted) return;
    await AppStorage.saveSignature(bytes);
    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Signatures', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _drawNew,
                  icon: const Icon(Icons.draw),
                  label: const Text('Draw new'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_saved.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No saved signatures. Draw one to reuse it later.'),
              )
            else
              SizedBox(
                height: 180,
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2,
                  children: _saved.map((path) {
                    return GestureDetector(
                      onTap: () {
                        try {
                          final bytes = File(path).readAsBytesSync();
                          Navigator.pop(context, bytes);
                        } catch (_) {
                          Navigator.pop(context);
                        }
                      },
                      onLongPress: () async {
                        await AppStorage.deleteSignature(path);
                        _load();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.file(File(path), fit: BoxFit.contain),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
            if (_saved.isNotEmpty)
              const Text('Long-press a signature to delete it.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _SignaturePad extends StatefulWidget {
  const _SignaturePad();

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: const Color(0x00000000),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Draw your signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: Signature(
              controller: _controller,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _controller.clear(),
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  if (_controller.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  Uint8List? bytes;
                  try {
                    bytes = await _controller.toPngBytes();
                  } catch (_) {}
                  if (context.mounted) Navigator.pop(context, bytes);
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
