import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Adds a diagonal text watermark to every page, with a live preview.
class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  final _service = PdfToolsService();
  final _render = PdfRenderService();
  final _controller = TextEditingController(text: 'CONFIDENTIAL');

  String? _path;
  RenderedPage? _preview;
  Color _color = Colors.red;
  double _opacity = 0.25;
  double _angle = -45;
  bool _busy = false;

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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _preview = null;
    });
    final page = await _render.renderPage(path, 0, scale: 1.5);
    if (mounted) setState(() => _preview = page);
  }

  Future<void> _apply() async {
    if (_path == null || _controller.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = await _service.applyWatermark(
        _path!,
        _controller.text.trim(),
        color: _color,
        opacity: _opacity,
        angle: _angle,
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
      appBar: AppBar(title: const Text('Watermark')),
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
                            Transform.rotate(
                              angle: _angle * math.pi / 180,
                              child: Text(
                                _controller.text,
                                style: TextStyle(
                                  color: _color.withValues(alpha: _opacity),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Watermark text',
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
            const SizedBox(height: 8),
            Row(
              children: _colors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? [const BoxShadow(blurRadius: 4, color: Colors.black26)]
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
            FilledButton.icon(
              onPressed: (_path != null && !_busy) ? _apply : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.branding_watermark),
              label: const Text('Apply to All Pages'),
            ),
          ],
        ),
      ),
    );
  }
}
