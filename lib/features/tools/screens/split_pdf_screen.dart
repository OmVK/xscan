import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

enum SplitMode { ranges, everyPage, everyN, byBookmarks }

/// Splits a PDF by page ranges, every N pages, or at bookmarks.
class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  final _service = PdfToolsService();
  final _rangeController = TextEditingController();
  final _nController = TextEditingController(text: '10');
  String? _path;
  int _pageCount = 0;
  List<String> _output = [];
  bool _busy = false;
  SplitMode _mode = SplitMode.ranges;
  List<BookmarkInfo> _bookmarks = [];

  @override
  void dispose() {
    _rangeController.dispose();
    _nController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _output = [];
      _busy = true;
      _bookmarks = [];
    });
    try {
      final count = await _service.pageCount(path);
      final bms = await _service.readBookmarks(path);
      if (mounted) {
        setState(() {
          _pageCount = count;
          _bookmarks = bms;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to open: $e')));
      }
    }
  }

  Future<void> _splitRanges() async {
    if (_path == null) return;
    final ranges =
        PdfToolsService.parseRanges(_rangeController.text, _pageCount);
    if (ranges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid ranges, e.g. 1-3, 5, 8-10')),
      );
      return;
    }
    await _perform(() => _service.splitByRanges(_path!, ranges));
  }

  Future<void> _splitEach() async {
    if (_path == null) return;
    await _perform(() => _service.splitEveryPage(_path!));
  }

  Future<void> _splitEveryN() async {
    if (_path == null) return;
    final n = int.tryParse(_nController.text);
    if (n == null || n < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of pages')),
      );
      return;
    }
    final ranges = <List<int>>[];
    for (var i = 0; i < _pageCount; i += n) {
      ranges.add(List.generate(
          (i + n > _pageCount) ? _pageCount - i : n, (j) => i + j));
    }
    await _perform(() => _service.splitByRanges(_path!, ranges));
  }

  Future<void> _splitByBookmarks() async {
    if (_path == null || _bookmarks.isEmpty) return;
    // Build ranges from bookmark positions.
    final sorted = List<BookmarkInfo>.from(_bookmarks)
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    final ranges = <List<int>>[];
    for (var i = 0; i < sorted.length; i++) {
      final start = sorted[i].pageIndex;
      final end = (i + 1 < sorted.length)
          ? sorted[i + 1].pageIndex
          : _pageCount;
      ranges.add(List.generate(end - start, (j) => start + j));
    }
    await _perform(() => _service.splitByRanges(_path!, ranges));
  }

  Future<void> _perform(Future<List<String>> Function() task) async {
    setState(() => _busy = true);
    try {
      final out = await task();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _output = out;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${out.length} file(s)')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
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
                  : '${_path!.split(Platform.pathSeparator).last}  ($_pageCount pages)'),
            ),
            const SizedBox(height: 16),

            // Split mode selector
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(
                  value: SplitMode.ranges,
                  label: Text('Ranges'),
                  icon: Icon(Icons.tag),
                ),
                ButtonSegment(
                  value: SplitMode.everyPage,
                  label: Text('Each'),
                  icon: Icon(Icons.copy),
                ),
                ButtonSegment(
                  value: SplitMode.everyN,
                  label: Text('Every N'),
                  icon: Icon(Icons.format_list_numbered),
                ),
                ButtonSegment(
                  value: SplitMode.byBookmarks,
                  label: Text('Bookmarks'),
                  icon: Icon(Icons.bookmark),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),

            // Mode-specific input
            if (_mode == SplitMode.ranges) ...[
              TextField(
                controller: _rangeController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Page ranges',
                  hintText: 'e.g. 1-3, 5, 8-10',
                  helperText: 'Each group becomes a separate PDF',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_path != null && !_busy) ? _splitRanges : null,
                icon: const Icon(Icons.content_cut),
                label: const Text('Split by Ranges'),
              ),
            ],
            if (_mode == SplitMode.everyN) ...[
              TextField(
                controller: _nController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pages per split',
                  hintText: 'e.g. 10',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_path != null && !_busy) ? _splitEveryN : null,
                icon: const Icon(Icons.content_cut),
                label: const Text('Split Every N Pages'),
              ),
            ],
            if (_mode == SplitMode.byBookmarks) ...[
              if (_bookmarks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _path == null
                          ? 'Select a PDF to detect bookmarks'
                          : 'No bookmarks found in this PDF',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_bookmarks.length} bookmark(s) found:',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        ...(_bookmarks.take(5).map((b) => Text(
                            '  p.${b.pageIndex + 1}: ${b.title}',
                            style: const TextStyle(fontSize: 12)))),
                        if (_bookmarks.length > 5)
                          Text('  ...and ${_bookmarks.length - 5} more',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_path != null && !_busy && _bookmarks.isNotEmpty)
                    ? _splitByBookmarks
                    : null,
                icon: const Icon(Icons.content_cut),
                label: const Text('Split at Bookmarks'),
              ),
            ],
            if (_mode == SplitMode.everyPage) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_path != null && !_busy) ? _splitEach : null,
                icon: const Icon(Icons.auto_awesome_motion),
                label: const Text('Split into Single Pages'),
              ),
            ],

            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _output.isEmpty
                  ? const Center(child: Text('Results appear here.'))
                  : ListView.builder(
                      itemCount: _output.length,
                      itemBuilder: (_, i) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf,
                              color: Colors.red),
                          title: Text(
                              _output[i].split(Platform.pathSeparator).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => showPdfResult(context, _output[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
