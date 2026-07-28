import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:xscan/core/services/print_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

/// Shows a frosted glass success sheet with preview / share options for a produced PDF.
Future<void> showPdfResult(BuildContext context, String path) {
  final sizeKb = (File(path).lengthSync() / 1024).toStringAsFixed(0);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassColor = isDark
      ? const Color(0xFF161622).withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.92);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.08);

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: glassColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 44),
            ),
            const SizedBox(height: 12),
            const Text(
              'PDF Ready!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${path.split(Platform.pathSeparator).last} • $sizeKb KB',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Preview')),
                            body: SfPdfViewer.file(File(path)),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => ToolIO.share(path),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => PrintService.printPdf(path),
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
