import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Splits a PDF by page ranges or into single pages.
class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  final _service = PdfToolsService();
  final _rangeController = TextEditingController();
  String? _path;
  int _pageCount = 0;
  List<String> _output = [];
  bool _busy = false;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _output = [];
      _busy = true;
    });
    try {
      final count = _service.pageCount(path);
      if (mounted) {
        setState(() {
          _pageCount = count;
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_path != null && !_busy) ? _splitEach : null,
              icon: const Icon(Icons.auto_awesome_motion),
              label: const Text('Split into Single Pages'),
            ),
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
