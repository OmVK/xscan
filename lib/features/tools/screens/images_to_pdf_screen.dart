import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final _service = PdfToolsService();
  final List<String> _paths = [];
  bool _busy = false;

  Future<void> _add() async {
    final picked = await ToolIO.pickImages();
    if (picked.isEmpty) return;
    setState(() => _paths.addAll(picked));
  }

  Future<void> _create() async {
    if (_paths.isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = await _service.imagesToPdf(_paths);
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
      appBar: AppBar(title: const Text('Images to PDF')),
      body: _paths.isEmpty
          ? const Center(child: Text('Add images to build a PDF.'))
          : ReorderableGridPlaceholder(
              paths: _paths,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, item);
                });
              },
              onRemove: (index) => setState(() => _paths.removeAt(index)),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'addImg',
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Images'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'makePdf',
            backgroundColor: _paths.isNotEmpty
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            onPressed: (_paths.isNotEmpty && !_busy) ? _create : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: const Text('Create PDF'),
          ),
        ],
      ),
    );
  }
}

/// Simple reorderable grid of image thumbnails.
class ReorderableGridPlaceholder extends StatelessWidget {
  final List<String> paths;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;

  const ReorderableGridPlaceholder({
    super.key,
    required this.paths,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: paths.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        return Card(
          key: ValueKey('$index-${paths[index]}'),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(paths[index]),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            title: Text('Page ${index + 1}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onRemove(index),
            ),
          ),
        );
      },
    );
  }
}
