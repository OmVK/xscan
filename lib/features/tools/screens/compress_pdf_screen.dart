import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  final _service = PdfToolsService();
  String? _path;
  int? _originalBytes;
  bool _busy = false;

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _originalBytes = File(path).lengthSync();
    });
  }

  Future<void> _compress() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final out = await _service.compress(_path!);
      final newBytes = File(out).lengthSync();
      if (!mounted) return;
      setState(() => _busy = false);
      final saved = (_originalBytes ?? newBytes) - newBytes;
      final pct = _originalBytes != null && _originalBytes! > 0
          ? (saved / _originalBytes! * 100).clamp(0, 100).toStringAsFixed(0)
          : '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reduced by $pct%')),
      );
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Compress failed: $e')));
    }
  }

  String _fmt(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.compress, size: 72, color: Colors.blueGrey),
              const SizedBox(height: 16),
              if (_path == null)
                const Text('Pick a PDF to reduce its file size.')
              else ...[
                Text(
                  _path!.split(Platform.pathSeparator).last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Current size: ${_fmt(_originalBytes ?? 0)}'),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.file_open),
                label: Text(_path == null ? 'Choose PDF' : 'Choose Different'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_path != null && !_busy) ? _compress : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                label: const Text('Compress'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
