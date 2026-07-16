import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Builds a searchable PDF from images by adding an invisible OCR text layer.
class SearchablePdfScreen extends StatefulWidget {
  const SearchablePdfScreen({super.key});

  @override
  State<SearchablePdfScreen> createState() => _SearchablePdfScreenState();
}

class _SearchablePdfScreenState extends State<SearchablePdfScreen> {
  final _service = PdfToolsService();
  List<String> _images = [];
  bool _busy = false;
  int _done = 0;

  Future<void> _fromGallery() async {
    final images = await ToolIO.pickImages();
    if (images.isNotEmpty) setState(() => _images = images);
  }

  Future<void> _fromDocument() async {
    final images = await pickDocumentImages(context);
    if (images != null && images.isNotEmpty) {
      setState(() => _images = images);
    }
  }

  Future<void> _build() async {
    if (_images.isEmpty) return;
    setState(() {
      _busy = true;
      _done = 0;
    });
    try {
      final out = await _service.imagesToSearchablePdf(
        _images,
        onProgress: (done, _) {
          if (mounted) setState(() => _done = done);
        },
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
      appBar: AppBar(title: const Text('Searchable PDF')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recognizes text on each image and embeds an invisible, '
              'selectable text layer so the PDF is searchable.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _fromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _fromDocument,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Scanned'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _images.isEmpty
                  ? const Center(child: Text('No images selected.'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_images[i]), fit: BoxFit.cover),
                      ),
                    ),
            ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _images.isEmpty ? null : _done / _images.length,
                    ),
                    const SizedBox(height: 8),
                    Text('Recognizing $_done / ${_images.length}'),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: (_images.isNotEmpty && !_busy) ? _build : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Create Searchable PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
