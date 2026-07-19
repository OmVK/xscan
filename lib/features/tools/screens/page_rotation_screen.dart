import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class _PageThumb {
  _PageThumb(this.originalIndex, this.thumb) : uid = _counter++;
  static int _counter = 0;
  final int originalIndex;
  final Uint8List thumb;
  final int uid;
  int rotation = 0;
}

class PageRotationScreen extends StatefulWidget {
  const PageRotationScreen({super.key});

  @override
  State<PageRotationScreen> createState() => _PageRotationScreenState();
}

class _PageRotationScreenState extends State<PageRotationScreen> {
  final _renderService = PdfRenderService();
  final _toolsService = PdfToolsService();

  String? _path;
  final List<_PageThumb> _pages = [];
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
          _pages.add(_PageThumb(i, rendered[i].bytes));
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

  Future<void> _apply() async {
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
        title: 'Rotated',
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
        title: const Text('Rotate Pages'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: 'Apply rotations',
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _busy ? null : _apply,
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
                      const Text('Tap a page to rotate it 90\u00B0 clockwise.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Choose PDF'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final entry = _pages[index];
                    return GestureDetector(
                      onTap: _busy
                          ? null
                          : () => setState(
                              () => entry.rotation = (entry.rotation + 1) % 4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: RotatedBox(
                              quarterTurns: entry.rotation,
                              child: Image.memory(
                                entry.thumb,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Page ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (entry.rotation % 4 != 0)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${entry.rotation * 90}\u00B0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
