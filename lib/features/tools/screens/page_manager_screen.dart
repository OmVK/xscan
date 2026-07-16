import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class _PageEntry {
  _PageEntry(this.originalIndex, this.thumb) : uid = _counter++;
  static int _counter = 0;
  final int originalIndex;
  final Uint8List thumb;
  final int uid;
  int rotation = 0;
}

class PageManagerScreen extends StatefulWidget {
  const PageManagerScreen({super.key});

  @override
  State<PageManagerScreen> createState() => _PageManagerScreenState();
}

class _PageManagerScreenState extends State<PageManagerScreen> {
  final _renderService = PdfRenderService();
  final _toolsService = PdfToolsService();

  String? _path;
  final List<_PageEntry> _pages = [];
  bool _loading = false;
  bool _busy = false;

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _loading = true;
      _pages.clear();
    });
    try {
      final rendered = await _renderService.renderAll(path, scale: 0.6);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < rendered.length; i++) {
          _pages.add(_PageEntry(i, rendered[i].bytes));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open: $e')));
    }
  }

  Future<void> _saveChanges() async {
    if (_path == null || _pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final order = _pages.map((p) => p.originalIndex).toList();
      final rotations = <int, int>{
        for (final p in _pages)
          if (p.rotation % 4 != 0) p.originalIndex: p.rotation % 4,
      };
      final out = await _toolsService.extractPagesWithRotation(
        _path!,
        order,
        rotations: rotations,
        title: 'Pages',
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

  Future<void> _extractSingle(int listIndex) async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final out = await _toolsService.extractPages(
        _path!,
        [_pages[listIndex].originalIndex],
        title: 'Page_${listIndex + 1}',
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
      appBar: AppBar(
        title: const Text('Organize Pages'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: 'Save',
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _busy ? null : _saveChanges,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _path == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Reorder, delete or extract pages.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Choose PDF'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pages.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _pages.removeAt(oldIndex);
                      _pages.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final entry = _pages[index];
                    return Card(
                      key: ValueKey(entry.uid),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: RotatedBox(
                            quarterTurns: entry.rotation,
                            child: Image.memory(
                              entry.thumb,
                              width: 44,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text('Page ${index + 1}'),
                        subtitle: Text('Original #${entry.originalIndex + 1}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rotate',
                              icon: const Icon(Icons.rotate_90_degrees_cw),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => entry.rotation = (entry.rotation + 1) % 4),
                            ),
                            IconButton(
                              tooltip: 'Duplicate page',
                              icon: const Icon(Icons.copy_all),
                              onPressed: _busy
                                  ? null
                                  : () {
                                      final copy = _PageEntry(
                                          entry.originalIndex, entry.thumb)
                                        ..rotation = entry.rotation;
                                      setState(
                                          () => _pages.insert(index + 1, copy));
                                    },
                            ),
                            IconButton(
                              tooltip: 'Extract this page',
                              icon: const Icon(Icons.call_split),
                              onPressed:
                                  _busy ? null : () => _extractSingle(index),
                            ),
                            IconButton(
                              tooltip: 'Delete page',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _pages.length > 1
                                  ? () => setState(() => _pages.removeAt(index))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
