import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class BookmarkManagerScreen extends StatefulWidget {
  const BookmarkManagerScreen({super.key});

  @override
  State<BookmarkManagerScreen> createState() => _BookmarkManagerScreenState();
}

class _BookmarkManagerScreenState extends State<BookmarkManagerScreen> {
  final _toolsService = PdfToolsService();

  String? _path;
  final List<BookmarkInfo> _bookmarks = [];
  bool _loading = false;
  bool _busy = false;
  int _pageCount = 0;

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _loading = true;
      _bookmarks.clear();
    });
    try {
      final count = _toolsService.pageCount(path);
      final loaded = _toolsService.readBookmarks(path);
      if (!mounted) return;
      setState(() {
        _pageCount = count;
        _bookmarks.addAll(loaded);
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
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final out = await _toolsService.writeBookmarks(_path!, _bookmarks);
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

  Future<void> _addBookmark() async {
    final result = await _showBookmarkDialog();
    if (result == null) return;
    setState(() => _bookmarks.add(result));
  }

  Future<BookmarkInfo?> _showBookmarkDialog({BookmarkInfo? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final pageCtrl = TextEditingController(
        text: existing != null ? '${existing.pageIndex + 1}' : '');
    final result = await showDialog<BookmarkInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Bookmark' : 'Edit Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pageCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Page number',
                border: const OutlineInputBorder(),
                suffixText: 'of $_pageCount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final page = int.tryParse(pageCtrl.text.trim());
              if (title.isEmpty || page == null || page < 1 || page > _pageCount) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter valid title and page number')),
                );
                return;
              }
              Navigator.pop(
                  ctx, BookmarkInfo(title: title, pageIndex: page - 1));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    pageCtrl.dispose();
    return result;
  }

  void _deleteBookmark(int index) {
    setState(() => _bookmarks.removeAt(index));
  }

  Future<void> _editBookmark(int index) async {
    final result = await _showBookmarkDialog(existing: _bookmarks[index]);
    if (result == null) return;
    setState(() => _bookmarks[index] = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmark Manager'),
        actions: [
          if (_bookmarks.isNotEmpty)
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
      floatingActionButton: _path != null && !_loading
          ? FloatingActionButton(
              onPressed: _busy ? null : _addBookmark,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _path == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Add, edit or reorder bookmarks.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Choose PDF'),
                      ),
                    ],
                  ),
                )
              : _bookmarks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No bookmarks found.'),
                          const SizedBox(height: 8),
                          const Text('Tap + to add one.'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _addBookmark,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Bookmark'),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _bookmarks.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _bookmarks.removeAt(oldIndex);
                          _bookmarks.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final bm = _bookmarks[index];
                        return Card(
                          key: ValueKey('$index-${bm.title}-${bm.pageIndex}'),
                          child: ListTile(
                            leading: const Icon(Icons.bookmark),
                            title: Text(bm.title),
                            subtitle: Text('Page ${bm.pageIndex + 1}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed:
                                      _busy ? null : () => _editBookmark(index),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed:
                                      _busy ? null : () => _deleteBookmark(index),
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
