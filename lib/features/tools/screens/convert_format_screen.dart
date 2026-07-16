import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:xscan/core/services/image_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

/// Converts images between formats (PNG, JPG, TIFF, BMP, WEBP*).
class ConvertFormatScreen extends StatefulWidget {
  const ConvertFormatScreen({super.key});

  @override
  State<ConvertFormatScreen> createState() => _ConvertFormatScreenState();
}

class _ConvertFormatScreenState extends State<ConvertFormatScreen> {
  final List<String> _paths = [];
  String _format = 'png';
  bool _busy = false;

  static const _formats = ['png', 'jpg', 'tiff', 'bmp', 'webp'];

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    setState(() => _paths.addAll(files.map((f) => f.path)));
  }

  Future<void> _convert() async {
    if (_paths.isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = <String>[];
      for (final p in _paths) {
        out.add(await ImageService.convertFormat(p, _format));
      }
      await ToolIO.shareMany(out);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convert Image Format')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Output format: '),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _format,
                  items: _formats
                      .map((f) => DropdownMenuItem(
                          value: f, child: Text(f.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => _format = v ?? 'png'),
                ),
              ],
            ),
            if (_format == 'webp')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Note: WEBP falls back to PNG encoding on this platform.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _paths.isEmpty
                  ? const Center(child: Text('No images selected'))
                  : GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: _paths
                          .map((p) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(p),
                                        fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _paths.remove(p)),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
            ),
            FilledButton.icon(
              onPressed: _busy || _paths.isEmpty ? null : _convert,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.transform),
              label: const Text('Convert & Share'),
            ),
          ],
        ),
      ),
    );
  }
}
