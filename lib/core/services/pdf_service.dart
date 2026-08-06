import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/services/app_storage.dart';

import 'package:xscan/features/scanner/services/ocr_service.dart';

class PdfService {
  /// Builds and saves the PDF for [document] on a background isolate so the UI
  /// stays responsive. Pages are downscaled (max ~2200px) before embedding to
  /// keep the output small and memory low.
  Future<String> generatePdfFromDocument(
    ScanDocument document, {
    String? watermark,
    String? password,
  }) async {
    final allFilePaths = [document.filePath, ...?document.additionalFilePaths];

    final bytes = await Isolate.run(() async {
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

      for (final path in allFilePaths) {
        final imageFile = File(path);
        if (!imageFile.existsSync()) continue;
        final imageBytes = _downscale(path);
        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      // Note: pdf.save() returned standalone; isolate IO is pure Dart.
      return pdf.save();
    });

    if (password != null && password.isNotEmpty) {
      return _encryptAndSave(bytes, password);
    }

    return await AppStorage.writePdf(document.title, bytes);
  }

  /// Reads + downscales an image to at most 2200px on its longest edge so
  /// multi-page scans don't embed full-resolution bitmaps into the PDF.
  static Uint8List _downscale(String path) {
    final raw = File(path).readAsBytesSync();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      return Uint8List.fromList(raw);
    }

    var image = decoded;
    final longest = math.max(image.width, image.height);
    if (longest > 2000) {
      image = image.width >= image.height
          ? img.copyResize(image, width: 2000)
          : img.copyResize(image, height: 2000);
    }
    final isPng = RegExp(r'\.png$', caseSensitive: false).hasMatch(path);
    return isPng ? img.encodePng(image) : img.encodeJpg(image, quality: 90);
  }

  /// Generates a Searchable & Editable PDF with precise OCR text overlays matching coordinates.
  Future<String> generateSearchablePdfFromOcr(OcrResult result) async {
    final pdf = pw.Document();
    final imagePath = result.imagePath;

    final imgW = result.imageWidth > 0 ? result.imageWidth.toDouble() : 1000.0;
    final imgH = result.imageHeight > 0 ? result.imageHeight.toDouble() : 1400.0;

    final format = PdfPageFormat(imgW, imgH);

    pw.MemoryImage? bgImage;
    if (imagePath != null && File(imagePath).existsSync()) {
      final bytes = await File(imagePath).readAsBytes();
      bgImage = pw.MemoryImage(bytes);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              if (bgImage != null)
                pw.Image(bgImage, fit: pw.BoxFit.fill),

              // Erase original text locations when moved or edited
              ...result.lines
                  .where((l) => (l.customLeft != null || l.customTop != null || l.isEdited) && l.isWhiteout)
                  .map((line) {
                return pw.Positioned(
                  left: line.box.left,
                  top: line.box.top,
                  child: pw.SizedBox(
                    width: line.box.width.clamp(10.0, imgW),
                    height: line.box.height.clamp(10.0, imgH),
                    child: pw.Container(
                      color: PdfColor.fromInt(line.backgroundColor.toARGB32()),
                    ),
                  ),
                );
              }),

              ...result.lines.map((line) {
                final left = line.effectiveLeft;
                final top = line.effectiveTop;
                final width = line.box.width.clamp(10.0, imgW);
                final height = line.box.height.clamp(10.0, imgH);
                final fontSize = (height * 0.75).clamp(8.0, 48.0);

                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.SizedBox(
                    width: width,
                    height: height,
                    child: pw.Container(
                      color: line.isWhiteout
                          ? PdfColor.fromInt(line.backgroundColor.toARGB32())
                          : null,
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        line.currentText,
                        style: pw.TextStyle(
                          fontSize: fontSize,
                          color: PdfColor.fromInt(line.textColor.toARGB32()),
                          fontWeight: line.isEdited
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    return AppStorage.writeExport('Searchable_OCR_Document_${DateTime.now().millisecondsSinceEpoch}.pdf', bytes);
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
