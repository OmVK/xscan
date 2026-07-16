import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:xscan/core/services/print_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

/// Shows a success sheet with preview / share options for a produced PDF.
Future<void> showPdfResult(BuildContext context, String path) {
  final sizeKb = (File(path).lengthSync() / 1024).toStringAsFixed(0);
  return showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text('Done', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${path.split(Platform.pathSeparator).last}  •  $sizeKb KB',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 12),
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
  );
}
