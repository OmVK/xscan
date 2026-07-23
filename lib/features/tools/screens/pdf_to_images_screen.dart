import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  final _render = PdfRenderService();
  String? _path;
  List<String> _output = [];
  bool _busy = false;
  int _done = 0;
  int _total = 0;

  // DPI options: scale factor maps to approximate DPI (96 DPI = scale 1.0)
  double _scale = 2.0;
  String _format = 'png';

  static const _dpiOptions = <(double, String)>[
    (0.75, '72 DPI'),
    (1.0, '96 DPI'),
    (1.5, '144 DPI'),
    (2.0, '192 DPI'),
    (3.0, '288 DPI'),
    (4.0, '384 DPI'),
  ];

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _output = [];
    });
  }

  Future<void> _convert() async {
    if (_path == null) return;
    setState(() {
      _busy = true;
      _done = 0;
      _total = 0;
    });
    try {
      final files = await _render.renderAllToFiles(
        _path!,
        scale: _scale,
        format: _format == 'jpeg' ? 'jpeg' : 'png',
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _output = files;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${files.length} images')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dpiLabel = _dpiOptions.firstWhere((e) => e.$1 == _scale).$2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Images'),
        actions: [
          if (_output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => ToolIO.shareMany(_output),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.file_open),
              label: Text(_path == null
                  ? 'Choose PDF'
                  : _path!.split(Platform.pathSeparator).last),
            ),
            const SizedBox(height: 16),

            // Settings panel
            if (_path != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Export Settings',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),

                    // DPI selector
                    Row(
                      children: [
                        const Icon(Icons.high_quality, size: 20),
                        const SizedBox(width: 8),
                        const Text('Resolution:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<double>(
                            segments: _dpiOptions
                                .map((e) => ButtonSegment(
                                      value: e.$1,
                                      label: Text(e.$2.split(' ').first, style: const TextStyle(fontSize: 11)),
                                    ))
                                .toList(),
                            selected: {_scale},
                            onSelectionChanged: _busy
                                ? null
                                : (v) => setState(() => _scale = v.first),
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '  $dpiLabel — ${(_scale * 96).round()} pixels per inch',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                    ),

                    const SizedBox(height: 12),

                    // Format selector
                    Row(
                      children: [
                        const Icon(Icons.image, size: 20),
                        const SizedBox(width: 8),
                        const Text('Format:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'png', label: Text('PNG')),
                            ButtonSegment(value: 'jpeg', label: Text('JPEG')),
                          ],
                          selected: {_format},
                          onSelectionChanged: _busy
                              ? null
                              : (v) => setState(() => _format = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            if (_busy) ...[
              LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total),
              const SizedBox(height: 8),
              Text('Rendering page $_done of $_total'),
            ],
            Expanded(
              child: _output.isEmpty
                  ? Center(
                      child: Text(
                        'No images yet.',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _output.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_output[i]), fit: BoxFit.cover),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: Colors.black54,
                                child: Text(
                                  'Page ${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            FilledButton.icon(
              onPressed: (_path != null && !_busy) ? _convert : null,
              icon: const Icon(Icons.image),
              label: Text(_output.isEmpty ? 'Convert to Images' : 'Re-export'),
            ),
          ],
        ),
      ),
    );
  }
}
