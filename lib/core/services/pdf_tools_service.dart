import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';

/// Kinds of overlay a user can flatten onto a PDF page in the editor.
enum PdfOverlayType { text, image, highlight, ink, underline }

/// Supported interactive form field types.
enum PdfFormFieldType { text, checkbox }

/// Lightweight description of a PDF form field for the fill-forms UI.
class PdfFormFieldInfo {
  PdfFormFieldInfo({
    required this.name,
    required this.type,
    required this.value,
  });

  final String name;
  final PdfFormFieldType type;
  final String value;
}

/// A single editable element placed on a page.
///
/// Positions are stored **normalized** (0..1) relative to the page so they map
/// cleanly between the on-screen preview and the real PDF point grid.
class PdfOverlay {
  PdfOverlay({
    required this.type,
    required this.pageIndex,
    this.rect = Rect.zero,
    this.text = '',
    this.color = Colors.black,
    this.fontSize = 14,
    this.imageBytes,
    this.points = const [],
    this.strokeWidth = 3,
  });

  final PdfOverlayType type;
  final int pageIndex;

  /// Normalized rectangle (for text/image/highlight).
  Rect rect;
  String text;
  Color color;
  double fontSize;
  Uint8List? imageBytes;

  /// Normalized points (for ink strokes).
  List<Offset> points;
  double strokeWidth;
}

class PdfToolsService {
  /// Merges multiple PDF files into a single document.
  Future<String> merge(List<String> paths, {String title = 'Merged'}) async {
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;

    for (final path in paths) {
      final source = PdfDocument(inputBytes: File(path).readAsBytesSync());
      _copyPages(source, output, List.generate(source.pages.count, (i) => i));
      source.dispose();
    }

    final bytes = await output.save();
    output.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Produces a new PDF containing only [pageIndices] in the given order.
  /// Works for delete (omit pages), reorder (change order) and split (subset).
  Future<String> extractPages(
    String path,
    List<int> pageIndices, {
    String title = 'Pages',
  }) async {
    final source = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    _copyPages(source, output, pageIndices);
    final bytes = await output.save();
    source.dispose();
    output.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Splits a PDF into multiple documents, one per [ranges] entry.
  /// Each range is a list of 0-based page indices.
  Future<List<String>> splitByRanges(
    String path,
    List<List<int>> ranges, {
    String title = 'Split',
  }) async {
    final outputs = <String>[];
    for (var i = 0; i < ranges.length; i++) {
      if (ranges[i].isEmpty) continue;
      final out = await extractPages(
        path,
        ranges[i],
        title: '${title}_part${i + 1}',
      );
      outputs.add(out);
    }
    return outputs;
  }

  /// Splits a PDF into single-page files.
  Future<List<String>> splitEveryPage(String path,
      {String title = 'Page'}) async {
    final count = pageCount(path);
    return splitByRanges(
      path,
      List.generate(count, (i) => [i]),
      title: title,
    );
  }

  /// Parses a range spec like "1-3, 5, 8-10" into lists of 0-based indices,
  /// clamped to [maxPages]. Each comma-separated token becomes one output.
  static List<List<int>> parseRanges(String spec, int maxPages) {
    final groups = <List<int>>[];
    for (final token in spec.split(',')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      final indices = <int>[];
      if (t.contains('-')) {
        final parts = t.split('-');
        if (parts.length != 2) continue;
        final a = int.tryParse(parts[0].trim());
        final b = int.tryParse(parts[1].trim());
        if (a == null || b == null) continue;
        final start = a < b ? a : b;
        final end = a < b ? b : a;
        for (var i = start; i <= end; i++) {
          if (i >= 1 && i <= maxPages) indices.add(i - 1);
        }
      } else {
        final n = int.tryParse(t);
        if (n != null && n >= 1 && n <= maxPages) indices.add(n - 1);
      }
      if (indices.isNotEmpty) groups.add(indices);
    }
    return groups;
  }

  /// Duplicates the pages at [pageIndices], inserting a copy right after each.
  Future<String> duplicatePages(
    String path,
    Set<int> pageIndices, {
    String title = 'Duplicated',
  }) async {
    final count = pageCount(path);
    final order = <int>[];
    for (var i = 0; i < count; i++) {
      order.add(i);
      if (pageIndices.contains(i)) order.add(i);
    }
    return extractPages(path, order, title: title);
  }

  /// Flattens all annotations and form fields into static page content, and
  /// re-saves. Prevents further editing of annotations/fields.
  Future<String> flatten(String path, {String title = 'Flattened'}) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    try {
      doc.form.flattenAllFields();
    } catch (_) {
      // No form or already flat.
    }
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final annots = page.annotations;
      try {
        annots.flattenAllAnnotations();
      } catch (_) {}
    }
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Returns the raw bytes of the PDF (for printing).
  Future<Uint8List> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// Reads the interactive form fields from a PDF (text & checkbox supported).
  List<PdfFormFieldInfo> readFormFields(String path) {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final result = <PdfFormFieldInfo>[];
    try {
      final form = doc.form;
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (field is PdfTextBoxField) {
          result.add(PdfFormFieldInfo(
            name: field.name ?? 'Field ${i + 1}',
            type: PdfFormFieldType.text,
            value: field.text,
          ));
        } else if (field is PdfCheckBoxField) {
          result.add(PdfFormFieldInfo(
            name: field.name ?? 'Field ${i + 1}',
            type: PdfFormFieldType.checkbox,
            value: field.isChecked ? 'true' : 'false',
          ));
        }
      }
    } catch (_) {
    } finally {
      doc.dispose();
    }
    return result;
  }

  /// Fills the given text/checkbox fields (keyed by field name) and saves.
  Future<String> fillForm(
    String path,
    Map<String, String> values, {
    bool flatten = false,
    String title = 'Filled',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final form = doc.form;
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      final name = field.name;
      if (name == null || !values.containsKey(name)) continue;
      final v = values[name]!;
      if (field is PdfTextBoxField) {
        field.text = v;
      } else if (field is PdfCheckBoxField) {
        field.isChecked = v == 'true';
      }
    }
    if (flatten) {
      try {
        form.flattenAllFields();
      } catch (_) {}
    }
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Re-saves the PDF as an archival PDF/A-1b document by rasterizing each
  /// source page into a new conformance-tagged document.
  Future<String> exportPdfA(String path, {String title = 'PDF-A'}) async {
    final source = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final out = PdfDocument(conformanceLevel: PdfConformanceLevel.a1b);
    out.pageSettings.margins.all = 0;
    try {
      for (var i = 0; i < source.pages.count; i++) {
        final srcPage = source.pages[i];
        final template = srcPage.createTemplate();
        out.pageSettings.size = srcPage.size;
        final page = out.pages.add();
        page.graphics.drawPdfTemplate(template, Offset.zero, srcPage.size);
      }
      final bytes = await out.save();
      return AppStorage.writePdf(title, bytes);
    } finally {
      source.dispose();
      out.dispose();
    }
  }

  /// Re-saves the PDF with maximum compression.
  Future<String> compress(String path, {String title = 'Compressed'}) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    doc.compressionLevel = PdfCompressionLevel.best;
    doc.fileStructure.crossReferenceType =
        PdfCrossReferenceType.crossReferenceStream;
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Builds a PDF from a list of image files, one image per page.
  Future<String> imagesToPdf(
    List<String> imagePaths, {
    String title = 'Document',
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 0;

    for (final imgPath in imagePaths) {
      final file = File(imgPath);
      if (!file.existsSync()) continue;
      final bitmap = PdfBitmap(file.readAsBytesSync());
      final page = doc.pages.add();
      final size = page.getClientSize();
      final rect = _fitRect(
        bitmap.width.toDouble(),
        bitmap.height.toDouble(),
        size.width,
        size.height,
      );
      page.graphics.drawImage(bitmap, rect);
    }

    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Flattens editor [overlays] onto the PDF at [path] and saves a new file.
  Future<String> applyOverlays(
    String path,
    List<PdfOverlay> overlays, {
    String title = 'Edited',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());

    for (final overlay in overlays) {
      if (overlay.pageIndex < 0 || overlay.pageIndex >= doc.pages.count) {
        continue;
      }
      final page = doc.pages[overlay.pageIndex];
      final size = page.getClientSize();
      final g = page.graphics;

      switch (overlay.type) {
        case PdfOverlayType.text:
          g.drawString(
            overlay.text,
            PdfStandardFont(PdfFontFamily.helvetica, overlay.fontSize),
            brush: PdfSolidBrush(_toPdfColor(overlay.color)),
            bounds: Rect.fromLTWH(
              overlay.rect.left * size.width,
              overlay.rect.top * size.height,
              overlay.rect.width * size.width,
              overlay.rect.height * size.height,
            ),
          );
          break;
        case PdfOverlayType.image:
          if (overlay.imageBytes != null) {
            g.drawImage(
              PdfBitmap(overlay.imageBytes!),
              Rect.fromLTWH(
                overlay.rect.left * size.width,
                overlay.rect.top * size.height,
                overlay.rect.width * size.width,
                overlay.rect.height * size.height,
              ),
            );
          }
          break;
        case PdfOverlayType.highlight:
          g.save();
          g.setTransparency(0.35);
          g.drawRectangle(
            brush: PdfSolidBrush(_toPdfColor(overlay.color)),
            bounds: Rect.fromLTWH(
              overlay.rect.left * size.width,
              overlay.rect.top * size.height,
              overlay.rect.width * size.width,
              overlay.rect.height * size.height,
            ),
          );
          g.restore();
          break;
        case PdfOverlayType.ink:
          if (overlay.points.length >= 2) {
            final pen = PdfPen(
              _toPdfColor(overlay.color),
              width: overlay.strokeWidth,
            );
            for (var i = 0; i < overlay.points.length - 1; i++) {
              final a = overlay.points[i];
              final b = overlay.points[i + 1];
              g.drawLine(
                pen,
                Offset(a.dx * size.width, a.dy * size.height),
                Offset(b.dx * size.width, b.dy * size.height),
              );
            }
          }
          break;
        case PdfOverlayType.underline:
          final y = (overlay.rect.top + overlay.rect.height) * size.height;
          g.drawLine(
            PdfPen(_toPdfColor(overlay.color), width: overlay.strokeWidth),
            Offset(overlay.rect.left * size.width, y),
            Offset((overlay.rect.left + overlay.rect.width) * size.width, y),
          );
          break;
      }
    }

    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Produces a new PDF with [pageIndices] in order, applying optional
  /// per-source-page rotation (quarter turns clockwise: 0..3).
  Future<String> extractPagesWithRotation(
    String path,
    List<int> pageIndices, {
    Map<int, int> rotations = const {},
    String title = 'Pages',
  }) async {
    final source = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;

    for (final index in pageIndices) {
      if (index < 0 || index >= source.pages.count) continue;
      final srcPage = source.pages[index];
      final template = srcPage.createTemplate();
      output.pageSettings.size = srcPage.size;
      final page = output.pages.add();
      page.graphics.drawPdfTemplate(template, Offset.zero, srcPage.size);
      final turns = (rotations[index] ?? 0) % 4;
      if (turns != 0) page.rotation = _rotateAngle(turns);
    }

    final bytes = await output.save();
    source.dispose();
    output.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Stamps diagonal watermark [text] across every page.
  Future<String> applyWatermark(
    String path,
    String text, {
    Color color = Colors.red,
    double opacity = 0.25,
    double angle = -45,
    String title = 'Watermarked',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final size = page.getClientSize();
      final fontSize = (size.width / (text.length.clamp(4, 40)) * 1.6)
          .clamp(20.0, 90.0);
      final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize,
          style: PdfFontStyle.bold);
      final g = page.graphics;
      g.save();
      g.setTransparency(opacity.clamp(0.0, 1.0));
      g.translateTransform(size.width / 2, size.height / 2);
      g.rotateTransform(angle);
      final textSize = font.measureString(text);
      g.drawString(
        text,
        font,
        brush: PdfSolidBrush(_toPdfColor(color)),
        bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2,
            textSize.width, textSize.height),
      );
      g.restore();
    }
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Encrypts a PDF with a user (open) password.
  Future<String> setPassword(
    String path,
    String userPassword, {
    String? currentPassword,
    String title = 'Protected',
  }) async {
    final doc = PdfDocument(
      inputBytes: File(path).readAsBytesSync(),
      password: currentPassword,
    );
    doc.security.algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6;
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword = userPassword;
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Removes password protection (requires the current password to open).
  Future<String> removePassword(
    String path,
    String currentPassword, {
    String title = 'Unlocked',
  }) async {
    final doc = PdfDocument(
      inputBytes: File(path).readAsBytesSync(),
      password: currentPassword,
    );
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Extracts all selectable text from a PDF.
  String extractText(String path, {String? password}) {
    final doc = PdfDocument(
      inputBytes: File(path).readAsBytesSync(),
      password: password,
    );
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return text;
  }

  /// Builds a searchable PDF from images: each page shows the image with an
  /// invisible (transparency-0) OCR text layer positioned over the words.
  Future<String> imagesToSearchablePdf(
    List<String> imagePaths, {
    String title = 'Searchable',
    void Function(int done, int total)? onProgress,
  }) async {
    final ocr = OcrService();
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 0;

    try {
      for (var i = 0; i < imagePaths.length; i++) {
        final imgPath = imagePaths[i];
        final file = File(imgPath);
        if (!file.existsSync()) continue;
        final result = await ocr.extractStructured(imgPath);
        final pw = result.imageWidth.toDouble();
        final ph = result.imageHeight.toDouble();

        doc.pageSettings.size = Size(pw, ph);
        final page = doc.pages.add();
        page.graphics.drawImage(
          PdfBitmap(file.readAsBytesSync()),
          Rect.fromLTWH(0, 0, pw, ph),
        );

        final g = page.graphics;
        for (final line in result.lines) {
          final box = line.box;
          if (box.height <= 0) continue;
          g.save();
          g.setTransparency(0);
          g.drawString(
            line.text,
            PdfStandardFont(PdfFontFamily.helvetica, box.height * 0.8),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(box.left, box.top, box.width, box.height),
          );
          g.restore();
        }
        onProgress?.call(i + 1, imagePaths.length);
      }

      final bytes = await doc.save();
      doc.dispose();
      return AppStorage.writePdf(title, bytes);
    } finally {
      ocr.dispose();
    }
  }

  PdfPageRotateAngle _rotateAngle(int turns) {
    switch (turns) {
      case 1:
        return PdfPageRotateAngle.rotateAngle90;
      case 2:
        return PdfPageRotateAngle.rotateAngle180;
      case 3:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  /// Returns the page count of a PDF file.
  int pageCount(String path) {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  void _copyPages(PdfDocument source, PdfDocument output, List<int> indices) {
    for (final index in indices) {
      if (index < 0 || index >= source.pages.count) continue;
      final srcPage = source.pages[index];
      final template = srcPage.createTemplate();
      output.pageSettings.size = srcPage.size;
      final page = output.pages.add();
      page.graphics.drawPdfTemplate(template, Offset.zero, srcPage.size);
    }
  }

  Rect _fitRect(double imgW, double imgH, double boxW, double boxH) {
    if (imgW <= 0 || imgH <= 0) return Rect.fromLTWH(0, 0, boxW, boxH);
    final scale = (boxW / imgW).clamp(0.0, boxH / imgH);
    final w = imgW * scale;
    final h = imgH * scale;
    return Rect.fromLTWH((boxW - w) / 2, (boxH - h) / 2, w, h);
  }

  PdfColor _toPdfColor(Color c) => PdfColor(
        (c.r * 255).round(),
        (c.g * 255).round(),
        (c.b * 255).round(),
      );

  /// Renders a signature drawing into trimmed PNG bytes (helper for editor).
  static Future<Uint8List?> imageToPng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}
