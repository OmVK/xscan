import 'package:flutter/material.dart';

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
  final pdfs = files.where((f) => f.isPdf).map((f) => f.path).toList();
  final images = files.where((f) => !f.isPdf).map((f) => f.path).toList();

  // Opening a single PDF (e.g. from a browser download / file manager) jumps
  // straight into the full editor with the sign / text / highlight / draw tools.
  if (pdfs.length == 1 && images.isEmpty) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(pdfPath: pdfs.first),
      ),
    );
    return;
  }

  await showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imported ${files.length} file(s)',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
