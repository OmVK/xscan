import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final _service = PdfToolsService();
  final List<String> _paths = [];
  bool _busy = false;

  Future<void> _add() async {
    final picked = await pickInAppPdf(context);
    if (picked == null) return;
    setState(() => _paths.add(picked));
  }

  Future<void> _merge() async {
    if (_paths.length < 2) return;
    setState(() => _busy = true);
    try {
      final out = await _service.merge(_paths);
      if (!mounted) return;
      setState(() => _busy = false);
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Merge failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs')),
      body: _paths.isEmpty
          ? const Center(child: Text('Add at least two PDFs to merge.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _paths.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final name = _paths[index].split(Platform.pathSeparator).last;
                return Card(
                  key: ValueKey('$index-${_paths[index]}'),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _paths.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Add PDF'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'merge',
            backgroundColor: _paths.length >= 2
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            onPressed: (_paths.length >= 2 && !_busy) ? _merge : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.merge),
            label: const Text('Merge'),
          ),
        ],
      ),
    );
  }
}
