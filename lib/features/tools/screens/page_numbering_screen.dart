import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class PageNumberingScreen extends StatefulWidget {
  const PageNumberingScreen({super.key});

  @override
  State<PageNumberingScreen> createState() => _PageNumberingScreenState();
}

class _PageNumberingScreenState extends State<PageNumberingScreen> {
  final _service = PdfToolsService();
  final _render = PdfRenderService();
  final _formatController = TextEditingController(text: 'Page {X}');
  final _rangeController = TextEditingController();

  String? _path;
  RenderedPage? _preview;
  int _pageCount = 0;
  PageNumberPosition _position = PageNumberPosition.bottomCenter;
  double _fontSize = 10;
  Color _color = Colors.black;
  bool _allPages = true;
  bool _busy = false;

  static const _positions = [
    (PageNumberPosition.topLeft, 'TL'),
    (PageNumberPosition.topCenter, 'TC'),
    (PageNumberPosition.topRight, 'TR'),
    (PageNumberPosition.bottomLeft, 'BL'),
    (PageNumberPosition.bottomCenter, 'BC'),
    (PageNumberPosition.bottomRight, 'BR'),
  ];

  static const _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.grey,
    Colors.orange,
  ];

  @override
  void dispose() {
    _formatController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _preview = null;
    });
    final count = _service.pageCount(path);
    final page = await _render.renderPage(path, 0, scale: 1.5);
    if (mounted) {
      setState(() {
        _pageCount = count;
        _preview = page;
      });
    }
  }

  List<int>? _getIndices() {
    if (_allPages) return null;
    final ranges =
        PdfToolsService.parseRanges(_rangeController.text, _pageCount);
    if (ranges.isEmpty) return null;
    return ranges.expand((r) => r).toList();
  }

  Future<void> _apply() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final out = await _service.addPageNumbers(
        _path!,
        pageIndices: _getIndices(),
        position: _position,
        format: _formatController.text.isEmpty
            ? 'Page {X}'
            : _formatController.text,
        fontSize: _fontSize,
        color: _color,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Numbers')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black12,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: _path == null
                  ? const Text('Choose a PDF to preview')
                  : _preview == null
                      ? const CircularProgressIndicator()
                      : Image.memory(_preview!.bytes),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _formatController,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      hintText: 'Page {X}',
                      helperText: '{X} = page, {Y} = total',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.file_open),
                  label: Text(_path == null ? 'PDF' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Position', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _positions.map((p) {
                final selected = p.$1 == _position;
                return ChoiceChip(
                  label: Text(p.$2),
                  selected: selected,
                  onSelected: (_) => setState(() => _position = p.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Size')),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 8,
                    max: 24,
                    divisions: 16,
                    label: _fontSize.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(_fontSize.toStringAsFixed(0)),
                ),
              ],
            ),
            Row(
              children: _colors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? [
                              const BoxShadow(
                                  blurRadius: 4, color: Colors.black26)
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('All pages')),
                ButtonSegment(value: false, label: Text('Custom range')),
              ],
              selected: {_allPages},
              onSelectionChanged: (v) => setState(() => _allPages = v.first),
            ),
            if (!_allPages)
              TextField(
                controller: _rangeController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: 'e.g. 1-3, 5, 8-10',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_path != null && !_busy) ? _apply : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pin),
              label: const Text('Add Page Numbers'),
            ),
          ],
        ),
      ),
    );
  }
}
