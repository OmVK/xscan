import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

class MetadataField {
  MetadataField({required this.label, this.icon}) : controller = TextEditingController();
  final String label;
  final TextEditingController controller;
  final IconData? icon;
}

class PdfMetadataScreen extends StatefulWidget {
  const PdfMetadataScreen({super.key});

  @override
  State<PdfMetadataScreen> createState() => _PdfMetadataScreenState();
}

class _PdfMetadataScreenState extends State<PdfMetadataScreen> {
  String? _path;
  bool _loading = false;
  bool _saving = false;
  PdfDocument? _doc;

  late final MetadataField _title;
  late final MetadataField _author;
  late final MetadataField _subject;
  late final MetadataField _keywords;
  late final MetadataField _creator;
  late final MetadataField _producer;

  @override
  void initState() {
    super.initState();
    _title = MetadataField(label: 'Title', icon: Icons.title);
    _author = MetadataField(label: 'Author', icon: Icons.person);
    _subject = MetadataField(label: 'Subject', icon: Icons.subject);
    _keywords = MetadataField(label: 'Keywords', icon: Icons.tag);
    _creator = MetadataField(label: 'Creator', icon: Icons.create);
    _producer = MetadataField(label: 'Producer', icon: Icons.precision_manufacturing);
  }

  @override
  void dispose() {
    _title.controller.dispose();
    _author.controller.dispose();
    _subject.controller.dispose();
    _keywords.controller.dispose();
    _creator.controller.dispose();
    _producer.controller.dispose();
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await File(path).readAsBytes();
      _doc?.dispose();
      _doc = PdfDocument(inputBytes: bytes);

      final info = _doc!.documentInformation;
      _title.controller.text = info.title;
      _author.controller.text = info.author;
      _subject.controller.text = info.subject;
      _keywords.controller.text = info.keywords;
      _creator.controller.text = info.creator;
      _producer.controller.text = info.producer;

      setState(() {
        _path = path;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read PDF: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_doc == null || _path == null) return;
    setState(() => _saving = true);

    try {
      final info = _doc!.documentInformation;
      info.title = _title.controller.text.trim();
      info.author = _author.controller.text.trim();
      info.subject = _subject.controller.text.trim();
      info.keywords = _keywords.controller.text.trim();
      info.creator = _creator.controller.text.trim();
      info.producer = _producer.controller.text.trim();

      final bytes = await _doc!.save();
      final dir = Directory.systemTemp;
      final outFile = File('${dir.path}/metadata_edited.pdf');
      await outFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);
      await showPdfResult(context, outFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  int? get _pageCount => _doc?.pages.count;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Metadata'),
        actions: [
          if (_doc != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _save,
              tooltip: 'Save metadata',
            ),
        ],
      ),
      body: _path == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 72, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text('Pick a PDF to view and edit its metadata.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _pick,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Choose PDF'),
                  ),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // File info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _path!.split(Platform.pathSeparator).last,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _infoChip('$_pageCount pages', Icons.book),
                              const SizedBox(width: 8),
                              _infoChip(
                                '${(File(_path!).lengthSync() / 1024).toStringAsFixed(0)} KB',
                                Icons.storage,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Document Properties',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    _metadataField(_title),
                    _metadataField(_author),
                    _metadataField(_subject),
                    _metadataField(_keywords),
                    _metadataField(_creator),
                    _metadataField(_producer),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pick,
                            icon: const Icon(Icons.file_open),
                            label: const Text('Change PDF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Save Metadata'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _metadataField(MetadataField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: field.controller,
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon: field.icon != null ? Icon(field.icon, size: 20) : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
