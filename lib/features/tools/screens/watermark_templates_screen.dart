import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class WatermarkTemplatesScreen extends StatefulWidget {
  const WatermarkTemplatesScreen({super.key});

  @override
  State<WatermarkTemplatesScreen> createState() =>
      _WatermarkTemplatesScreenState();
}

class _WatermarkTemplatesScreenState extends State<WatermarkTemplatesScreen> {
  final _service = PdfToolsService();
  final _render = PdfRenderService();
  final _customController = TextEditingController();
  final _rangeController = TextEditingController();

  String? _path;
  RenderedPage? _preview;
  int _pageCount = 0;

  String? _selectedTemplate;
  bool _useCustom = false;
  double _opacity = 0.25;
  double _angle = -45;
  double _fontSize = 48;
  Color _color = Colors.red;
  bool _allPages = true;
  bool _busy = false;

  static const _templates = [
    ('CONFIDENTIAL', Color(0xFFC62828)),
    ('DRAFT', Color(0xFF616161)),
    ('COPY', Color(0xFF616161)),
    ('DO NOT DISTRIBUTE', Color(0xFFC62828)),
    ('SAMPLE', Color(0xFF1565C0)),
    ('INTERNAL USE ONLY', Color(0xFFEF6C00)),
    ('APPROVED', Color(0xFF2E7D32)),
    ('REJECTED', Color(0xFFC62828)),
  ];

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.grey,
    Colors.orange,
    Colors.purple,
  ];

  @override
  void dispose() {
    _customController.dispose();
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

  String get _watermarkText {
    if (_useCustom) return _customController.text;
    return _selectedTemplate ?? '';
  }

  List<int>? _getIndices() {
    if (_allPages) return null;
    final ranges =
        PdfToolsService.parseRanges(_rangeController.text, _pageCount);
    if (ranges.isEmpty) return null;
    return ranges.expand((r) => r).toList();
  }

  Future<void> _apply() async {
    if (_path == null || _watermarkText.isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = await _service.applyWatermarkTemplate(
        _path!,
        _watermarkText,
        pageIndices: _getIndices(),
        opacity: _opacity,
        angle: _angle,
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
      appBar: AppBar(title: const Text('Watermark Templates')),
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
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.memory(_preview!.bytes),
                            if (_watermarkText.isNotEmpty)
                              Transform.rotate(
                                angle: _angle * 3.14159 / 180,
                                child: Text(
                                  _watermarkText,
                                  style: TextStyle(
                                    color:
                                        _color.withValues(alpha: _opacity),
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.file_open),
                  label: Text(_path == null ? 'PDF' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Choose a template',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._templates.map((t) {
                  final selected = !_useCustom && _selectedTemplate == t.$1;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTemplate = t.$1;
                      _useCustom = false;
                      _color = t.$2;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? t.$2 : Colors.grey.shade400,
                          width: selected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        color: selected
                            ? t.$2.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Text(
                        t.$1,
                        style: TextStyle(
                          color: t.$2,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setState(() {
                    _useCustom = true;
                    _selectedTemplate = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _useCustom
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                        width: _useCustom ? 2.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: _useCustom
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Text(
                      'CUSTOM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontSize: 11,
                        color: _useCustom
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_useCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Custom text',
                  hintText: 'Type watermark text...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
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
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Opacity')),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.05,
                    max: 1,
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Angle')),
                Expanded(
                  child: Slider(
                    value: _angle,
                    min: -90,
                    max: 90,
                    onChanged: (v) => setState(() => _angle = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Size')),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 20,
                    max: 90,
                    divisions: 70,
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
            const SizedBox(height: 8),
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
              onPressed: (_path != null && _watermarkText.isNotEmpty && !_busy)
                  ? _apply
                  : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.branding_watermark),
              label: const Text('Apply Watermark'),
            ),
          ],
        ),
      ),
    );
  }
}
