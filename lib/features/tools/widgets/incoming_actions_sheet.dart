import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:xscan/core/services/file_import_service.dart';
import 'package:xscan/core/services/incoming_share_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/screens/pdf_editor_screen.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Presents actions for files received from other apps (share / open-with).
Future<void> showIncomingActions(
  BuildContext context,
  List<IncomingFile> files,
) async {
  if (files.isEmpty) return;
  final rawPdfs = files.where((f) => f.isPdf).map((f) => f.path).toList();
  final images = files.where((f) => !f.isPdf).map((f) => f.path).toList();

  final pdfs = await Future.wait(rawPdfs.map((p) async {
    try {
      return await FileImportService.copyIntoStorage(p);
    } catch (_) {
      return p;
    }
  }));

  if (pdfs.length == 1 && images.isEmpty) {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(pdfPath: pdfs.first),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassColor = isDark
      ? const Color(0xFF161622).withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.92);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.08);

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: glassColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Imported ${files.length} file(s)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (pdfs.length == 1)
                  ListTile(
                    leading: const Icon(Icons.edit_document),
                    title: const Text('Edit & sign'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfEditorScreen(pdfPath: pdfs.first),
                        ),
                      );
                    },
                  ),
                if (pdfs.length == 1)
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Preview / share'),
                    onTap: () {
                      Navigator.pop(ctx);
                      showPdfResult(context, pdfs.first);
                    },
                  ),
                if (pdfs.length > 1)
                  ListTile(
                    leading: const Icon(Icons.merge_type),
                    title: Text('Merge ${pdfs.length} PDFs'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _run(context, () => PdfToolsService().merge(pdfs));
                    },
                  ),
                if (images.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text('Create PDF from ${images.length} image(s)'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _run(
                          context, () => PdfToolsService().imagesToPdf(images));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.manage_search),
                    title: const Text('Create searchable PDF'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _run(context,
                          () => PdfToolsService().imagesToSearchablePdf(images));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _run(BuildContext context, Future<String> Function() task) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Working...')),
  );
  try {
    final out = await task();
    if (context.mounted) await showPdfResult(context, out);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}
