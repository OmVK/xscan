import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/services/app_storage.dart';

class PdfService {
  Future<String> generatePdfFromDocument(
    ScanDocument document, {
    String? watermark,
    String? password,
  }) async {
    final pdf = pw.Document();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      buildForeground: (pw.Context context) {
        if (watermark != null && watermark.isNotEmpty) {
          return pw.Center(
            child: pw.Transform.rotate(
              angle: -0.785,
              child: pw.Text(
                watermark,
                style: pw.TextStyle(
                  color: const PdfColor(0, 0, 0, 0.2),
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

    final bytes = await pdf.save();

    if (password != null && password.isNotEmpty) {
      return _encryptAndSave(bytes, password);
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final sanitizedTitle =
        document.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final outputFile = File('${outputDir.path}/$sanitizedTitle.pdf');
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  /// Encrypts PDF bytes with AES-256 using Syncfusion and returns the saved path.
  Future<String> _encryptAndSave(List<int> pdfBytes, String password) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    sfDoc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;
    sfDoc.security.userPassword = password;
    sfDoc.security.ownerPassword = password;
    final encryptedBytes = await sfDoc.save();
    sfDoc.dispose();
    return AppStorage.writePdf('Encrypted', encryptedBytes);
  }
}
