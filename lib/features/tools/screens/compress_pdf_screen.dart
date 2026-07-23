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
  int? _compressedBytes;
  String? _compressedPath;
  bool _busy = false;

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() {
      _path = path;
      _originalBytes = File(path).lengthSync();
      _compressedBytes = null;
      _compressedPath = null;
    });
  }

  Future<void> _compress() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final out = await _service.compress(_path!);
      final newBytes = File(out).lengthSync();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _compressedBytes = newBytes;
        _compressedPath = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Compress failed: $e')));
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  double? get _reductionPercent {
    if (_originalBytes == null || _compressedBytes == null || _originalBytes == 0) {
      return null;
    }
    return ((_originalBytes! - _compressedBytes!) / _originalBytes! * 100)
        .clamp(0, 100)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                const SizedBox(height: 16),

                // Before/After comparison
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _sizeCard('Original', _originalBytes, theme.colorScheme.error),
                          const Icon(Icons.arrow_forward, color: Colors.grey),
                          _sizeCard('Compressed', _compressedBytes, theme.colorScheme.primary),
                        ],
                      ),
                      if (_reductionPercent != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.trending_down,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_reductionPercent!.toStringAsFixed(1)}% smaller',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved ${_fmt((_originalBytes ?? 0) - (_compressedBytes ?? 0))}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
              if (_compressedPath != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => showPdfResult(context, _compressedPath!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Result'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeCard(String label, int? bytes, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          bytes != null ? _fmt(bytes) : '--',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }
}
