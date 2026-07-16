import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';

/// Exports each page of a PDF as a PNG image.
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
            const SizedBox(height: 12),
            if (_busy) ...[
              LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total),
              const SizedBox(height: 8),
              Text('Rendering $_done / $_total'),
            ],
            Expanded(
              child: _output.isEmpty
                  ? const Center(child: Text('No images yet.'))
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
                        child: Image.file(File(_output[i]), fit: BoxFit.cover),
                      ),
                    ),
            ),
            FilledButton.icon(
              onPressed: (_path != null && !_busy) ? _convert : null,
              icon: const Icon(Icons.image),
              label: const Text('Convert to Images'),
            ),
          ],
        ),
      ),
    );
  }
}
