import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class RedactPdfScreen extends StatefulWidget {
  const RedactPdfScreen({super.key});

  @override
  State<RedactPdfScreen> createState() => _RedactPdfScreenState();
}

class _RedactPdfScreenState extends State<RedactPdfScreen> {
  final _service = PdfToolsService();
  final _render = PdfRenderService();

  String? _path;
  RenderedPage? _page;
  int _pageCount = 0;
  int _pageIndex = 0;
  bool _loading = false;
  bool _saving = false;

  final List<PdfOverlay> _overlays = [];
  Offset? _dragStart;
  Rect? _draftRect;
  Color _redactColor = Colors.black;

  List<PdfOverlay> get _pageOverlays =>
      _overlays.where((o) => o.pageIndex == _pageIndex).toList();

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _page = null;
      _overlays.clear();
      _pageIndex = 0;
    });
    final count = await _service.pageCount(path);
    _pageCount = count;
    await _loadPage(0);
  }

  Future<void> _loadPage(int index) async {
    if (_path == null) return;
    setState(() => _loading = true);
    final rendered = await _render.renderPage(_path!, index, scale: 2.0);
    if (!mounted) return;
    setState(() {
      _pageIndex = index;
      _page = rendered;
      _loading = false;
    });
  }

  Offset _toNorm(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  void _onPanStart(DragStartDetails d, Size size) {
    final n = _toNorm(d.localPosition, size);
    setState(() {
      _dragStart = n;
      _draftRect = Rect.fromLTWH(n.dx, n.dy, 0, 0);
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_dragStart == null) return;
    final n = _toNorm(d.localPosition, size);
    setState(() {
      _draftRect = Rect.fromPoints(_dragStart!, n);
    });
  }

  void _onPanEnd() {
    if (_draftRect != null) {
      final r = Rect.fromLTWH(
        _draftRect!.left,
        _draftRect!.top,
        _draftRect!.width.abs(),
        _draftRect!.height.abs(),
      );
      if (r.width > 0.02 && r.height > 0.02) {
        setState(() {
          _overlays.add(PdfOverlay(
            type: PdfOverlayType.redact,
            pageIndex: _pageIndex,
            rect: r,
            color: _redactColor,
          ));
        });
      }
    }
    setState(() {
      _draftRect = null;
      _dragStart = null;
    });
  }

  void _removeOverlay(PdfOverlay o) {
    setState(() => _overlays.remove(o));
  }

  Future<void> _apply() async {
    if (_path == null || _overlays.isEmpty) return;
    setState(() => _saving = true);
    try {
      final out = await _service.applyOverlays(
        _path!,
        _overlays,
        title: 'Redacted',
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redact PDF'),
        actions: [
          if (_overlays.isNotEmpty)
            IconButton(
              tooltip: 'Undo last',
              icon: const Icon(Icons.undo),
              onPressed: () {
                setState(() {
                  _overlays.removeLast();
                });
              },
            ),
          IconButton(
            tooltip: 'Apply redactions',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed:
                (_path != null && _overlays.isNotEmpty && !_saving)
                    ? _apply
                    : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_path == null)
            Expanded(
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Choose PDF'),
                ),
              ),
            )
          else ...[
            Expanded(child: _buildCanvas()),
            _buildPager(),
            // Color picker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Text('Color: ', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  ...[Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.yellow].map((c) {
                    final selected = _redactColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _redactColor = c),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (_pageOverlays.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${_pageOverlays.length} redaction(s) on this page',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
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
              onPanStart: (d) => _onPanStart(d, size),
              onPanUpdate: (d) => _onPanUpdate(d, size),
              onPanEnd: (_) => _onPanEnd(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(_page!.bytes, fit: BoxFit.fill),
                  ),
                  ..._pageOverlays.map((o) => Positioned(
                        left: o.rect.left * w,
                        top: o.rect.top * h,
                        width: o.rect.width * w,
                        height: o.rect.height * h,
                        child: GestureDetector(
                          onTap: () => _removeOverlay(o),
                          child: Container(color: Colors.black),
                        ),
                      )),
                  if (_draftRect != null)
                    Positioned(
                      left: _draftRect!.left * w,
                      top: _draftRect!.top * h,
                      width: _draftRect!.width.abs() * w,
                      height: _draftRect!.height.abs() * h,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPager() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _pageIndex > 0 ? () => _loadPage(_pageIndex - 1) : null,
          ),
          Text('Page ${_pageIndex + 1} / $_pageCount'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _pageIndex < _pageCount - 1
                ? () => _loadPage(_pageIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
