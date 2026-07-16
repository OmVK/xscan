import 'dart:io';
import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Thin wrapper over the `printing` plugin for PDFs and images.
class PrintService {
  static Future<void> printPdf(String path) async {
    final bytes = await File(path).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> printPdfBytes(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> sharePdf(String path, {String name = 'document.pdf'}) async {
    final bytes = await File(path).readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}
