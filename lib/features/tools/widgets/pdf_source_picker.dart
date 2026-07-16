import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:xscan/core/services/file_import_service.dart';
import 'package:xscan/core/services/pdf_service.dart';

/// Lets the user choose a PDF source: a previously produced PDF from the app's
/// storage, or one of their scanned documents (rendered to PDF on demand).
///
/// Returns the absolute path of the chosen PDF, or null if cancelled.
Future<String?> pickInAppPdf(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _PdfSourcePicker(),
    ),
  );
}

/// Lets the user pick a scanned document; returns its ordered image paths
/// (cover + additional pages), or null if cancelled.
Future<List<String>?> pickDocumentImages(BuildContext context) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _DocumentImagePicker(),
    ),
  );
}

class _PdfSourcePicker extends ConsumerStatefulWidget {
  const _PdfSourcePicker();

  @override
  ConsumerState<_PdfSourcePicker> createState() => _PdfSourcePickerState();
}

class _DocumentImagePicker extends ConsumerWidget {
  const _DocumentImagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsStreamProvider);
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Choose a scanned document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (docs) {
              final withImages =
                  docs.where((d) => d.filePath.isNotEmpty).toList();
              if (withImages.isEmpty) {
                return const Center(child: Text('No scanned documents yet.'));
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: withImages.map((doc) {
                  final images = <String>[
                    doc.filePath,
                    ...?doc.additionalFilePaths,
                  ].where((p) => File(p).existsSync()).toList();
                  final hasImage = File(doc.filePath).existsSync();
                  return ListTile(
                    leading: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(File(doc.filePath),
                                width: 40, height: 40, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.article),
                    title: Text(doc.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${images.length} page(s)'),
                    onTap: images.isEmpty
                        ? null
                        : () => Navigator.pop(context, images),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PdfSourcePickerState extends ConsumerState<_PdfSourcePicker> {
  List<File> _existingPdfs = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final pdfDir = Directory(p.join(base.path, 'pdfs'));
      final files = <File>[];
      if (await pdfDir.exists()) {
        for (final e in pdfDir.listSync()) {
          if (e is File && e.path.toLowerCase().endsWith('.pdf')) {
            files.add(e);
          }
        }
      }
      // Also include PDFs written directly under documents dir (legacy).
      for (final e in Directory(base.path).listSync()) {
        if (e is File && e.path.toLowerCase().endsWith('.pdf')) {
          files.add(e);
        }
      }
      files.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
      if (mounted) {
        setState(() {
          _existingPdfs = files;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _browseDevice() async {
    try {
      final path = await FileImportService.pickPdf();
      if (path != null && mounted) Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _fromDocument(ScanDocument doc) async {
    setState(() => _generating = true);
    try {
      final path = await PdfService().generatePdfFromDocument(doc);
      if (mounted) Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsStreamProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Choose a PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _browseDevice,
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse device storage'),
            ),
          ),
        ),
        if (_generating) const LinearProgressIndicator(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_existingPdfs.isNotEmpty) ...[
                      const _SectionHeader('Recent PDFs'),
                      ..._existingPdfs.map((f) => ListTile(
                            leading: const Icon(Icons.picture_as_pdf,
                                color: Colors.red),
                            title: Text(
                              p.basename(f.path),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${(f.lengthSync() / 1024).toStringAsFixed(0)} KB',
                            ),
                            onTap: () => Navigator.pop(context, f.path),
                          )),
                    ],
                    const _SectionHeader('Scanned Documents'),
                    docsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e'),
                      ),
                      data: (docs) {
                        final withImages = docs
                            .where((d) => d.filePath.isNotEmpty)
                            .toList();
                        if (withImages.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No scanned documents yet.'),
                          );
                        }
                        return Column(
                          children: withImages.map((doc) {
                            final hasImage = File(doc.filePath).existsSync();
                            return ListTile(
                              leading: hasImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(doc.filePath),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.article),
                              title: Text(
                                doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(doc.category),
                              onTap: _generating
                                  ? null
                                  : () => _fromDocument(doc),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
