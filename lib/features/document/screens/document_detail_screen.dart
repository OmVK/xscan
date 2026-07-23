import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/services/pdf_service.dart';
import 'package:xscan/core/services/ai_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xscan/core/providers/settings_provider.dart';
import 'package:xscan/core/providers/document_provider.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final ScanDocument document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  final PdfService _pdfService = PdfService();
  String? _pdfPath;
  bool _isLoading = true;

  Future<void> _addPage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Page',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Page',
            ),
          ],
        );

        if (croppedFile == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final newImagePath = croppedFile.path;
        final scriptKey = ref.read(ocrScriptProvider);
        final script =
            OcrService.scripts[scriptKey] ?? TextRecognitionScript.latin;
        final ocrService = OcrService(script: script);
        final newText = await ocrService.extractTextFromImage(newImagePath);
        ocrService.dispose();
        
        if (newText == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OCR failed for this image')),
            );
          }
          return;
        }
        
        // Update document
        widget.document.additionalFilePaths = [
          ...?widget.document.additionalFilePaths,
          newImagePath
        ];
        
        if (newText.isNotEmpty) {
          final existingText = widget.document.ocrText ?? '';
          widget.document.ocrText = existingText.isEmpty 
              ? newText 
              : '$existingText\n\n--- Page ${(widget.document.additionalFilePaths?.length ?? 0) + 1} ---\n\n$newText';
        }
        
        // Save to DB
        final isarService = ref.read(isarServiceProvider);
        await isarService.saveDocument(widget.document);
        
        // Regenerate PDF
        await _generatePdf();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add page: $e')),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final watermark = ref.read(pdfWatermarkProvider);
      final password = ref.read(pdfPasswordProvider);

      // If document is hidden, decrypt files for PDF generation.
      ScanDocument doc = widget.document;
      if (doc.isHidden) {
        final isarService = ref.read(isarServiceProvider);
        final tempPaths = <String>[];
        final allPaths = [doc.filePath, ...?doc.additionalFilePaths];
        for (final p in allPaths) {
          tempPaths.add(await isarService.decryptForViewing(p));
        }
        doc = ScanDocument()
          ..id = doc.id
          ..title = doc.title
          ..filePath = tempPaths.first
          ..additionalFilePaths =
              tempPaths.length > 1 ? tempPaths.sublist(1) : null
          ..ocrText = doc.ocrText
          ..dateCreated = doc.dateCreated
          ..category = doc.category
          ..tags = doc.tags
          ..folder = doc.folder
          ..notes = doc.notes
          ..docType = doc.docType
          ..fileType = doc.fileType
          ..isFavorite = doc.isFavorite
          ..isTrashed = doc.isTrashed
          ..isArchived = doc.isArchived
          ..isHidden = doc.isHidden
          ..barcodeFormat = doc.barcodeFormat;
      }

      final path = await _pdfService.generatePdfFromDocument(
        doc,
        watermark: watermark,
        password: password,
      );
      if (mounted) {
        setState(() {
          _pdfPath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfPath == null) return;
    
    await SharePlus.instance.share(ShareParams(
      files: [XFile(_pdfPath!)],
      text: 'Check out this document scanned with XScan: ${widget.document.title}',
    ));
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to permanently delete this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final isarService = ref.read(isarServiceProvider);
      await isarService.deleteDocument(widget.document.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _renameDocument() async {
    final controller = TextEditingController(text: widget.document.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty && newTitle != widget.document.title) {
      widget.document.title = newTitle.trim();
      final isarService = ref.read(isarServiceProvider);
      await isarService.saveDocument(widget.document);
      setState(() {});
    }
  }

  Future<void> _editFolderAndTags() async {
    final folderController =
        TextEditingController(text: widget.document.category);
    final tagsController =
        TextEditingController(text: widget.document.tags.join(', '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder & Tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: folderController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Folder',
                hintText: 'e.g. Receipts',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tags (comma separated)',
                hintText: 'e.g. tax, 2026',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final folder = folderController.text.trim();
      widget.document.category = folder.isEmpty ? 'General' : folder;
      widget.document.tags = tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await ref.read(isarServiceProvider).saveDocument(widget.document);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleFlag(String flag) async {
    final doc = widget.document;
    final isarService = ref.read(isarServiceProvider);
    switch (flag) {
      case 'favorite':
        doc.isFavorite = !doc.isFavorite;
        HapticFeedback.lightImpact();
        await isarService.saveDocument(doc);
        break;
      case 'archive':
        doc.isArchived = !doc.isArchived;
        await isarService.saveDocument(doc);
        break;
      case 'hidden':
        if (!doc.isHidden) {
          await isarService.hideDocument(doc.id);
        } else {
          await isarService.unhideDocument(doc.id);
        }
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _moveToTrash() async {
    await ref.read(isarServiceProvider).trashDocument(widget.document.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: widget.document.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notes'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Add notes…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      widget.document.notes = controller.text.trim();
      await ref.read(isarServiceProvider).saveDocument(widget.document);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openAiAssistant() async {
    final text = widget.document.ocrText ?? '';
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text available. Run OCR first.')),
      );
      return;
    }
    final docType = AiService.detectDocType(text);
    final title = AiService.suggestTitle(text, docType);
    final folder = AiService.suggestFolder(docType);
    final summary = AiService.summarize(text);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                const Text('AI Assistant',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _aiRow('Type', docType),
            _aiRow('Suggested title', title, onApply: () async {
              widget.document.title = title;
              await ref.read(isarServiceProvider).saveDocument(widget.document);
              if (mounted) setState(() {});
            }),
            _aiRow('Suggested folder', folder, onApply: () async {
              widget.document.category = folder;
              await ref.read(isarServiceProvider).saveDocument(widget.document);
              if (mounted) setState(() {});
            }),
            const Divider(height: 32),
            const Text('Summary',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(summary),

            // Invoice / Receipt extraction
            if (docType == 'Invoice' || docType == 'Receipt') ...[
              const Divider(height: 32),
              Text(
                docType == 'Invoice' ? 'Invoice Details' : 'Receipt Details',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final data = docType == 'Invoice'
                    ? AiService.extractInvoice(text)
                    : {'Total': AiService.extractReceiptTotal(text) ?? 'Not found'};
                if (data.isEmpty) {
                  return const Text('No structured data found.');
                }
                return Column(
                  children: data.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                        Expanded(
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )).toList(),
                );
              }),
            ],

            // Business card extraction
            if (docType == 'Business Card') ...[
              const Divider(height: 32),
              const Text('Contact Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final card = AiService.extractBusinessCard(text);
                if (card.isEmpty) {
                  return const Text('No contact data found.');
                }
                return Column(
                  children: card.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                        Expanded(
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )).toList(),
                );
              }),
            ],

            const Divider(height: 32),
            _AiQuestionBox(text: text),
          ],
        ),
      ),
    );
  }

  Widget _aiRow(String label, String value, {Future<void> Function()? onApply}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
          if (onApply != null)
            TextButton(onPressed: onApply, child: const Text('Apply')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            icon: Icon(widget.document.isFavorite
                ? Icons.star
                : Icons.star_border),
            color: widget.document.isFavorite ? Colors.amber : null,
            onPressed: () => _toggleFlag('favorite'),
            tooltip: 'Favorite',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _openAiAssistant,
            tooltip: 'AI Assistant',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _renameDocument,
            tooltip: 'Rename',
          ),
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            onPressed: _editFolderAndTags,
            tooltip: 'Folder & Tags',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'notes':
                  _editNotes();
                  break;
                case 'archive':
                  _toggleFlag('archive');
                  break;
                case 'hidden':
                  _toggleFlag('hidden');
                  break;
                case 'trash':
                  _moveToTrash();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'notes', child: Text('Notes')),
              PopupMenuItem(
                  value: 'archive',
                  child: Text(widget.document.isArchived
                      ? 'Unarchive'
                      : 'Archive')),
              PopupMenuItem(
                  value: 'hidden',
                  child:
                      Text(widget.document.isHidden ? 'Unhide' : 'Hide')),
              const PopupMenuItem(
                  value: 'trash', child: Text('Move to Trash')),
            ],
          ),
          if (widget.document.ocrText != null && widget.document.ocrText!.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy OCR Text',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.document.ocrText!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('OCR Text copied to clipboard')),
                );
              },
            ),
          if (!_isLoading && _pdfPath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePdf,
              tooltip: 'Export as PDF',
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _deleteDocument,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating Premium PDF...'),
                ],
              ),
            )
          : _pdfPath != null
              ? Hero(
                  tag: widget.document.id.toString(),
                  child: SfPdfViewer.file(
                    File(_pdfPath!),
                    password: ref.read(pdfPasswordProvider),
                  ),
                )
              : const Center(child: Text('Failed to load document.')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addPage,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Page'),
      ),
    );
  }
}

class _AiQuestionBox extends StatefulWidget {
  final String text;
  const _AiQuestionBox({required this.text});

  @override
  State<_AiQuestionBox> createState() => _AiQuestionBoxState();
}

class _AiQuestionBoxState extends State<_AiQuestionBox> {
  final _controller = TextEditingController();
  String? _answer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ask a question',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. What is the total?',
                  isDense: true,
                ),
                onSubmitted: (_) => _ask(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _ask, child: const Text('Ask')),
          ],
        ),
        if (_answer != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_answer!),
          ),
        ],
      ],
    );
  }

  void _ask() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _answer = AiService.answerQuestion(widget.text, q);
    });
  }
}
