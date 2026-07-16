import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/screens/text_tools_screen.dart';
import 'package:xscan/features/tools/services/tool_io.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';

/// Extracts selectable text from a PDF and lets the user copy or export it.
class PdfToTextScreen extends StatefulWidget {
  const PdfToTextScreen({super.key});

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  final _service = PdfToolsService();
  String? _path;
  String _text = '';
  bool _busy = false;

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _text = '';
      _busy = true;
    });
    try {
      final text = _service.extractText(path);
      if (mounted) {
        setState(() {
          _text = text.trim();
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _export() async {
    if (_text.isEmpty) return;
    final path =
        await AppStorage.writeExport('extracted.txt', utf8.encode(_text));
    await ToolIO.share(path);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Text'),
        actions: [
          if (hasText) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            IconButton(
                icon: const Icon(Icons.download), onPressed: _export),
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Text tools',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TextToolsScreen(
                    initialText: _text,
                    title: 'Text Tools',
                  ),
                ),
              ),
            ),
          ],
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
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : !hasText
                      ? const Center(
                          child: Text('No text extracted yet.\n'
                              'Scanned images need "Searchable PDF" first.',
                              textAlign: TextAlign.center))
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(_text),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
