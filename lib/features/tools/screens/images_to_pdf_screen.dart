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

  // Page size options
  String _pageSize = 'fit'; // 'fit', 'a4', 'letter', 'square'
  bool _landscape = false;

  static const _pageSizes = <(String, String, double, double)>[
    ('fit', 'Fit to Image', 0, 0),
    ('a4', 'A4 (210×297mm)', 595.28, 841.89),
    ('letter', 'Letter (8.5×11")', 612, 792),
    ('square', 'Square', 612, 612),
  ];

  Future<void> _add() async {
    final picked = await ToolIO.pickImages();
    if (picked.isEmpty) return;
    setState(() => _paths.addAll(picked));
  }

  Future<void> _create() async {
    if (_paths.isEmpty) return;
    setState(() => _busy = true);
    try {
      final sizeOption = _pageSizes.firstWhere((e) => e.$1 == _pageSize);
      final out = await _service.imagesToPdf(
        _paths,
        pageWidth: sizeOption.$3,
        pageHeight: sizeOption.$4,
        landscape: _landscape,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created PDF with ${_paths.length} pages')),
      );
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Images to PDF')),
      body: Column(
        children: [
          // Settings panel
          if (_paths.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Page Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.aspect_ratio, size: 20),
                      const SizedBox(width: 8),
                      const Text('Size:', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: _pageSizes
                              .map((e) => ButtonSegment(
                                    value: e.$1,
                                    label: Text(e.$2.split(' ').first, style: const TextStyle(fontSize: 11)),
                                  ))
                              .toList(),
                          selected: {_pageSize},
                          onSelectionChanged: (v) => setState(() => _pageSize = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_pageSize != 'fit') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.screen_rotation, size: 20),
                        const SizedBox(width: 8),
                        const Text('Orientation:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Portrait'),
                          selected: !_landscape,
                          onSelected: (_) => setState(() => _landscape = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Landscape'),
                          selected: _landscape,
                          onSelected: (_) => setState(() => _landscape = true),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '  ${_pageSizes.firstWhere((e) => e.$1 == _pageSize).$2}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),

          // Image list
          Expanded(
            child: _paths.isEmpty
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
          ),
        ],
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
            label: Text(_busy ? 'Creating...' : 'Create PDF'),
          ),
        ],
      ),
    );
  }
}

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
            subtitle: Text(
              paths[index].split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.outline),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
