import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/services/pdf_encryption.dart';

class PdfService {
  Future<String> generatePdfFromDocument(
    ScanDocument document, {
    String? watermark,
    String? password,
  }) async {
    final pdf = pw.Document();

    // Apply real RC4-128 password protection when a password is configured.
    if (password != null && password.isNotEmpty) {
      pdf.document.encryption = PdfStandardEncryption(
        pdf.document,
        userPassword: password,
      );
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      buildForeground: (pw.Context context) {
        if (watermark != null && watermark.isNotEmpty) {
          return pw.Center(
            child: pw.Transform.rotate(
              angle: -0.785, // -45 degrees roughly
              child: pw.Text(
                watermark,
                style: pw.TextStyle(
                  color: const PdfColor(0, 0, 0, 0.2), // Semi-transparent black
                  fontSize: 80,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        }
        return pw.SizedBox();
      },
    );

    final allFilePaths = [document.filePath, ...?(document.additionalFilePaths)];

    for (final path in allFilePaths) {
      final imageFile = File(path);
      if (!imageFile.existsSync()) continue;
      final imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    // Optional: Add OCR text on a second page
    if (document.ocrText != null && document.ocrText!.trim().isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Extracted Text',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  document.ocrText!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final sanitizedTitle = document.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final outputFile = File('${outputDir.path}/$sanitizedTitle.pdf');
    
    await outputFile.writeAsBytes(await pdf.save());
    
    return outputFile.path;
  }
}
