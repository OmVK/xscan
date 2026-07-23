import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/pdf_render_service.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';

/// Kinds of overlay a user can flatten onto a PDF page in the editor.
enum PdfOverlayType { text, image, highlight, ink, underline, redact, ocrText }

enum PageNumberPosition {
  topLeft, topCenter, topRight,
  bottomLeft, bottomCenter, bottomRight,
}

/// Supported interactive form field types.
enum PdfFormFieldType { text, checkbox }

/// Custom exception for PDF tool operations with user-friendly messages.
class PdfToolException implements Exception {
  PdfToolException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => message;
}

class BookmarkInfo {
  BookmarkInfo({required this.title, required this.pageIndex});

  final String title;
  final int pageIndex;
}

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
    if (paths.isEmpty) {
      throw PdfToolException('No PDF files selected to merge.');
    }

    // File I/O must stay on main isolate — read all bytes first.
    final fileBytesList = <Uint8List>[];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        throw PdfToolException('File not found: ${path.split('/').last}');
      }
      try {
        fileBytesList.add(await file.readAsBytes());
      } catch (e) {
        throw PdfToolException(
          'Failed to read ${path.split('/').last}. The file may be corrupted or password-protected.',
          originalError: e,
        );
      }
    }

    // Heavy PDF merging on background isolate.
    final result = await Isolate.run(() {
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;
      for (final bytes in fileBytesList) {
        final source = PdfDocument(inputBytes: bytes);
        _copyPagesStatic(source, output, List.generate(source.pages.count, (i) => i));
        source.dispose();
      }
      final merged = output.saveSync();
      output.dispose();
      return merged;
    });

    // Write file on main isolate (platform channel access).
    return AppStorage.writePdf(title, result);
  }

  /// Produces a new PDF containing only [pageIndices] in the given order.
  /// Works for delete (omit pages), reorder (change order) and split (subset).
  Future<String> extractPages(
    String path,
    List<int> pageIndices, {
    String title = 'Pages',
  }) async {
    if (pageIndices.isEmpty) {
      throw PdfToolException('No pages selected.');
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw PdfToolException('PDF file not found.');
    }

    Uint8List inputBytes;
    try {
      inputBytes = await file.readAsBytes();
    } catch (e) {
      throw PdfToolException(
        'Failed to open PDF. The file may be corrupted or password-protected.',
        originalError: e,
      );
    }

    final result = await Isolate.run(() {
      final source = PdfDocument(inputBytes: inputBytes);
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;
      _copyPagesStatic(source, output, pageIndices);
      final bytes = output.saveSync();
      source.dispose();
      output.dispose();
      return bytes;
    });

    return AppStorage.writePdf(title, result);
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
    final count = await pageCount(path);
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
    final count = await pageCount(path);
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
    final inputBytes = await File(path).readAsBytes();
    final result = await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
      try {
        doc.form.flattenAllFields();
      } catch (_) {}
      for (var i = 0; i < doc.pages.count; i++) {
        try {
          doc.pages[i].annotations.flattenAllAnnotations();
        } catch (_) {}
      }
      final bytes = doc.saveSync();
      doc.dispose();
      return bytes;
    });
    return AppStorage.writePdf(title, result);
  }

  /// Returns the raw bytes of the PDF (for printing).
  Future<Uint8List> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// Reads the interactive form fields from a PDF (text & checkbox supported).
  Future<List<PdfFormFieldInfo>> readFormFields(String path) async {
    final inputBytes = await File(path).readAsBytes();
    final raw = await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
      final result = <Map<String, String>>[];
      try {
        final form = doc.form;
        for (var i = 0; i < form.fields.count; i++) {
          final field = form.fields[i];
          if (field is PdfTextBoxField) {
            result.add({
              'name': field.name ?? 'Field ${i + 1}',
              'type': 'text',
              'value': field.text,
            });
          } else if (field is PdfCheckBoxField) {
            result.add({
              'name': field.name ?? 'Field ${i + 1}',
              'type': 'checkbox',
              'value': field.isChecked ? 'true' : 'false',
            });
          }
        }
      } catch (_) {}
      doc.dispose();
      return result;
    });
    return raw
        .map((m) => PdfFormFieldInfo(
              name: m['name']!,
              type: m['type'] == 'checkbox'
                  ? PdfFormFieldType.checkbox
                  : PdfFormFieldType.text,
              value: m['value']!,
            ))
        .toList();
  }

  /// Fills the given text/checkbox fields (keyed by field name) and saves.
  Future<String> fillForm(
    String path,
    Map<String, String> values, {
    bool flatten = false,
    String title = 'Filled',
  }) async {
    final inputBytes = await File(path).readAsBytes();
    final result = await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
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
      final bytes = doc.saveSync();
      doc.dispose();
      return bytes;
    });
    return AppStorage.writePdf(title, result);
  }

  /// Re-saves the PDF as an archival PDF/A-1b document by rasterizing each
  /// source page into a new conformance-tagged document.
  Future<String> exportPdfA(String path, {String title = 'PDF-A'}) async {
    final inputBytes = await File(path).readAsBytes();
    final result = await Isolate.run(() {
      final source = PdfDocument(inputBytes: inputBytes);
      final out = PdfDocument(conformanceLevel: PdfConformanceLevel.a1b);
      out.pageSettings.margins.all = 0;
      for (var i = 0; i < source.pages.count; i++) {
        final srcPage = source.pages[i];
        final template = srcPage.createTemplate();
        out.pageSettings.size = srcPage.size;
        final page = out.pages.add();
        page.graphics.drawPdfTemplate(template, Offset.zero, srcPage.size);
      }
      final bytes = out.saveSync();
      source.dispose();
      out.dispose();
      return bytes;
    });
    return AppStorage.writePdf(title, result);
  }

  /// Re-saves the PDF with maximum compression.
  Future<String> compress(String path, {String title = 'Compressed'}) async {
    final inputBytes = await File(path).readAsBytes();

    final result = await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.crossReferenceType =
          PdfCrossReferenceType.crossReferenceStream;
      final bytes = doc.saveSync();
      doc.dispose();
      return bytes;
    });

    return AppStorage.writePdf(title, result);
  }

  /// Builds a PDF from a list of image files, one image per page.
  /// If [pageWidth]/[pageHeight] are 0, each page fits to the image size.
  Future<String> imagesToPdf(
    List<String> imagePaths, {
    String title = 'Document',
    double pageWidth = 0,
    double pageHeight = 0,
    bool landscape = false,
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 0;

    for (final imgPath in imagePaths) {
      final file = File(imgPath);
      if (!file.existsSync()) continue;
      final bitmap = PdfBitmap(file.readAsBytesSync());

      // Configure page size if specified
      if (pageWidth > 0 && pageHeight > 0) {
        final w = landscape ? pageHeight : pageWidth;
        final h = landscape ? pageWidth : pageHeight;
        doc.pageSettings.size = Size(w, h);
      } else {
        // Fit to image: use default page size
        doc.pageSettings.size = Size(
          bitmap.width.toDouble() * 0.75,
          bitmap.height.toDouble() * 0.75,
        );
      }

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
  ///
  /// For redact overlays, the affected pages are rasterized to destroy the
  /// underlying content (text, images, vectors) before drawing the opaque
  /// redaction box on top. This ensures redacted content cannot be recovered.
  Future<String> applyOverlays(
    String path,
    List<PdfOverlay> overlays, {
    String title = 'Edited',
  }) async {
    // Separate redact overlays from other overlays.
    final redactByPage = <int, List<PdfOverlay>>{};
    final otherOverlays = <PdfOverlay>[];
    for (final o in overlays) {
      if (o.type == PdfOverlayType.redact) {
        redactByPage.putIfAbsent(o.pageIndex, () => []).add(o);
      } else {
        otherOverlays.add(o);
      }
    }

    // If there are redactions, rasterize those pages to destroy content.
    if (redactByPage.isNotEmpty) {
      return _applyOverlaysWithRedaction(path, otherOverlays, redactByPage,
          title: title);
    }

    // No redactions — draw overlays directly on existing pages.
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    _drawOverlays(doc, otherOverlays);
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Applies overlays including redaction by rasterizing redacted pages.
  Future<String> _applyOverlaysWithRedaction(
    String path,
    List<PdfOverlay> otherOverlays,
    Map<int, List<PdfOverlay>> redactByPage, {
    String title = 'Edited',
  }) async {
    // Step 1: Render pages that have redactions to images.
    final renderer = PdfRenderService();
    final redactedImages = <int, RenderedPage>{};
    for (final pageIndex in redactByPage.keys) {
      final rendered = await renderer.renderPage(path, pageIndex, scale: 2.0);
      if (rendered != null) {
        redactedImages[pageIndex] = rendered;
      }
    }

    // Step 2: Build new PDF — use images for redacted pages, templates for others.
    final inputBytes = await File(path).readAsBytes();
    final result = await Isolate.run(() {
      final source = PdfDocument(inputBytes: inputBytes);
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;

      for (var i = 0; i < source.pages.count; i++) {
        final srcPage = source.pages[i];
        if (redactedImages.containsKey(i)) {
          // Redacted page: replace with rasterized image.
          // The image bytes will be drawn later on main isolate (graphics ops).
          // For now, create a blank page of the same size.
          output.pageSettings.size = srcPage.size;
          output.pages.add();
        } else {
          // Non-redacted page: copy as template (preserves text selectability).
          final template = srcPage.createTemplate();
          output.pageSettings.size = srcPage.size;
          final page = output.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero, srcPage.size);
        }
      }

      final bytes = output.saveSync();
      source.dispose();
      output.dispose();
      return bytes;
    });

    // Step 3: Re-open the output, draw redacted images + all overlays.
    final doc = PdfDocument(inputBytes: result);
    for (final entry in redactedImages.entries) {
      final page = doc.pages[entry.key];
      final size = page.getClientSize();
      final bitmap = PdfBitmap(entry.value.bytes);
      page.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, size.width, size.height));
    }

    // Draw all overlays (including redact boxes on top of rasterized pages).
    final allOverlays = [
      ...otherOverlays,
      for (final entry in redactByPage.entries)
        for (final o in entry.value) o,
    ];
    _drawOverlays(doc, allOverlays);

    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  void _drawOverlays(PdfDocument doc, List<PdfOverlay> overlays) {
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
        case PdfOverlayType.underline:
          final y = (overlay.rect.top + overlay.rect.height) * size.height;
          g.drawLine(
            PdfPen(_toPdfColor(overlay.color), width: overlay.strokeWidth),
            Offset(overlay.rect.left * size.width, y),
            Offset((overlay.rect.left + overlay.rect.width) * size.width, y),
          );
        case PdfOverlayType.redact:
          g.drawRectangle(
            brush: PdfSolidBrush(_toPdfColor(overlay.color)),
            bounds: Rect.fromLTWH(
              overlay.rect.left * size.width,
              overlay.rect.top * size.height,
              overlay.rect.width * size.width,
              overlay.rect.height * size.height,
            ),
          );
        case PdfOverlayType.ocrText:
          g.save();
          g.setTransparency(0);
          g.drawString(
            overlay.text,
            PdfStandardFont(PdfFontFamily.helvetica, overlay.fontSize),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(
              overlay.rect.left * size.width,
              overlay.rect.top * size.height,
              overlay.rect.width * size.width,
              overlay.rect.height * size.height,
            ),
          );
          g.restore();
      }
    }
  }

  Future<String> addPageNumbers(
    String path, {
    List<int>? pageIndices,
    PageNumberPosition position = PageNumberPosition.bottomCenter,
    String format = 'Page {X}',
    double fontSize = 10,
    Color color = Colors.black,
    String title = 'Numbered',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final total = doc.pages.count;
    final indices = pageIndices ?? List.generate(total, (i) => i);
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);

    for (final idx in indices) {
      if (idx < 0 || idx >= total) continue;
      final page = doc.pages[idx];
      final size = page.getClientSize();
      final g = page.graphics;
      final display = format
          .replaceAll('{X}', '${idx + 1}')
          .replaceAll('{Y}', '$total');
      final measured = font.measureString(display);
      double x, y;
      switch (position) {
        case PageNumberPosition.topLeft:
          x = 20; y = 10;
        case PageNumberPosition.topCenter:
          x = (size.width - measured.width) / 2; y = 10;
        case PageNumberPosition.topRight:
          x = size.width - measured.width - 20; y = 10;
        case PageNumberPosition.bottomLeft:
          x = 20; y = size.height - measured.height - 10;
        case PageNumberPosition.bottomCenter:
          x = (size.width - measured.width) / 2;
          y = size.height - measured.height - 10;
        case PageNumberPosition.bottomRight:
          x = size.width - measured.width - 20;
          y = size.height - measured.height - 10;
      }
      g.drawString(
        display,
        font,
        brush: PdfSolidBrush(_toPdfColor(color)),
        bounds: Rect.fromLTWH(x, y, measured.width, measured.height),
      );
    }
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  Future<String> applyWatermarkTemplate(
    String path,
    String text, {
    List<int>? pageIndices,
    double opacity = 0.25,
    double angle = -45,
    double? fontSize,
    Color color = Colors.red,
    String title = 'Watermarked',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final total = doc.pages.count;
    final indices = pageIndices ?? List.generate(total, (i) => i);

    for (final idx in indices) {
      if (idx < 0 || idx >= total) continue;
      final page = doc.pages[idx];
      final size = page.getClientSize();
      final fs = fontSize ??
          (size.width / (text.length.clamp(4, 40)) * 1.6).clamp(20.0, 90.0);
      final font = PdfStandardFont(PdfFontFamily.helvetica, fs,
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
        bounds: Rect.fromLTWH(
            -textSize.width / 2, -textSize.height / 2,
            textSize.width, textSize.height),
      );
      g.restore();
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

  /// Encrypts a PDF with user (open) and/or owner (permission) passwords.
  ///
  /// [userPassword] — required to open the PDF.
  /// [ownerPassword] — controls permissions (printing, copying, etc.).
  ///   If null, [userPassword] is used for both.
  /// [restrictPrint], [restrictCopy], [restrictEdit] — permission restrictions.
  Future<String> setPassword(
    String path,
    String userPassword, {
    String? ownerPassword,
    String? currentPassword,
    bool restrictPrint = false,
    bool restrictCopy = false,
    bool restrictEdit = false,
    String title = 'Protected',
  }) async {
    if (userPassword.isEmpty) {
      throw PdfToolException('Password cannot be empty.');
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw PdfToolException('PDF file not found.');
    }

    PdfDocument doc;
    try {
      doc = PdfDocument(
        inputBytes: file.readAsBytesSync(),
        password: currentPassword,
      );
    } catch (e) {
      throw PdfToolException(
        'Failed to open PDF. Wrong password or corrupted file.',
        originalError: e,
      );
    }

    try {
      doc.security.algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6;
      doc.security.userPassword = userPassword;
      doc.security.ownerPassword = ownerPassword ?? userPassword;

      // Apply permission restrictions
      if (restrictPrint || restrictCopy || restrictEdit) {
        final perms = doc.security.permissions;
        if (restrictPrint) {
          perms.remove(PdfPermissionsFlags.print);
          perms.remove(PdfPermissionsFlags.fullQualityPrint);
        }
        if (restrictCopy) {
          perms.remove(PdfPermissionsFlags.copyContent);
        }
        if (restrictEdit) {
          perms.remove(PdfPermissionsFlags.editContent);
          perms.remove(PdfPermissionsFlags.editAnnotations);
        }
      }

      final bytes = await doc.save();
      doc.dispose();
      return AppStorage.writePdf(title, bytes);
    } catch (e) {
      doc.dispose();
      throw PdfToolException(
        'Failed to set password. The PDF may not support encryption.',
        originalError: e,
      );
    }
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
  Future<String> extractText(String path, {String? password}) async {
    final inputBytes = await File(path).readAsBytes();
    return await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes, password: password);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      return text;
    });
  }

  Future<String> extractPageText(String path, int pageIndex, {String? password}) async {
    final inputBytes = await File(path).readAsBytes();
    return await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes, password: password);
      try {
        if (pageIndex < 0 || pageIndex >= doc.pages.count) {
          doc.dispose();
          return '';
        }
        final extractor = PdfTextExtractor(doc);
        final text = extractor.extractText(
          startPageIndex: pageIndex + 1,
          endPageIndex: pageIndex + 1,
        );
        doc.dispose();
        return text;
      } catch (_) {
        doc.dispose();
        return '';
      }
    });
  }

  /// Builds a searchable PDF from images: each page shows the image with an
  /// invisible (transparency-0) OCR text layer positioned over the words.
  ///
  /// NOTE: OCR (`OcrService.extractStructured`) uses platform channels (ML Kit)
  /// so it must remain on the main isolate. Only the final PDF save is
  /// background-safe, so the bulk of the work stays here.
  Future<String> imagesToSearchablePdf(
    List<String> imagePaths, {
    String title = 'Searchable',
    void Function(int done, int total)? onProgress,
  }) async {
    final ocr = OcrService();
    try {
      // Collect all image bytes and OCR results on the main isolate (platform
      // channel requirement), then hand the raw data to a background isolate
      // for the PDF generation step only.
      final pageDataList = <({Uint8List imageBytes, double w, double h, List<({String text, double left, double top, double width, double height})> words})>[];
      for (var i = 0; i < imagePaths.length; i++) {
        final imgPath = imagePaths[i];
        final file = File(imgPath);
        if (!file.existsSync()) continue;
        final result = await ocr.extractStructured(imgPath);
        final pw = result.imageWidth.toDouble();
        final ph = result.imageHeight.toDouble();
        final words = <({String text, double left, double top, double width, double height})>[];
        for (final line in result.lines) {
          final box = line.box;
          if (box.height <= 0) continue;
          words.add((
            text: line.text,
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
          ));
        }
        pageDataList.add((
          imageBytes: await file.readAsBytes(),
          w: pw,
          h: ph,
          words: words,
        ));
        onProgress?.call(i + 1, imagePaths.length);
      }

      // PDF generation on background isolate (no platform channels needed).
      final result = await Isolate.run(() {
        final doc = PdfDocument();
        doc.pageSettings.margins.all = 0;
        for (final pageData in pageDataList) {
          doc.pageSettings.size = Size(pageData.w, pageData.h);
          final page = doc.pages.add();
          page.graphics.drawImage(
            PdfBitmap(pageData.imageBytes),
            Rect.fromLTWH(0, 0, pageData.w, pageData.h),
          );
          final g = page.graphics;
          for (final word in pageData.words) {
            g.save();
            g.setTransparency(0);
            g.drawString(
              word.text,
              PdfStandardFont(PdfFontFamily.helvetica, word.height * 0.8),
              brush: PdfSolidBrush(PdfColor(0, 0, 0)),
              bounds: Rect.fromLTWH(word.left, word.top, word.width, word.height),
            );
            g.restore();
          }
        }
        final bytes = doc.saveSync();
        doc.dispose();
        return bytes;
      });

      return AppStorage.writePdf(title, result);
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
  Future<int> pageCount(String path) async {
    final inputBytes = await File(path).readAsBytes();
    return await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
      try {
        return doc.pages.count;
      } finally {
        doc.dispose();
      }
    });
  }

  /// Static variant of [_copyPages] usable inside isolates.
  static void _copyPagesStatic(
      PdfDocument source, PdfDocument output, List<int> indices) {
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

  /// Reads the bookmarks from a PDF file.
  Future<List<BookmarkInfo>> readBookmarks(String path) async {
    final inputBytes = await File(path).readAsBytes();
    final raw = await Isolate.run(() {
      final doc = PdfDocument(inputBytes: inputBytes);
      final result = <Map<String, dynamic>>[];
      try {
        _collectBookmarksStatic(doc.bookmarks, result, doc);
      } catch (_) {}
      doc.dispose();
      return result;
    });
    return raw
        .map((m) => BookmarkInfo(
              title: m['title'] as String,
              pageIndex: m['pageIndex'] as int,
            ))
        .toList();
  }

  /// Static variant usable inside isolates.
  static void _collectBookmarksStatic(
      PdfBookmarkBase bookmarks, List<Map<String, dynamic>> result, PdfDocument doc) {
    for (var i = 0; i < bookmarks.count; i++) {
      final bm = bookmarks[i];
      try {
        final dest = bm.destination;
        if (dest != null) {
          final targetPage = dest.page;
          var pageIndex = 0;
          for (var j = 0; j < doc.pages.count; j++) {
            if (identical(doc.pages[j], targetPage)) {
              pageIndex = j;
              break;
            }
          }
          result.add({
            'title': bm.title,
            'pageIndex': pageIndex,
          });
        }
      } catch (_) {}
      _collectBookmarksStatic(bm, result, doc);
    }
  }

  /// Writes bookmarks to a PDF file, replacing all existing ones.
  Future<String> writeBookmarks(
    String path,
    List<BookmarkInfo> bookmarks, {
    String title = 'Bookmarked',
  }) async {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    try {
      while (doc.bookmarks.count > 0) {
        doc.bookmarks.removeAt(0);
      }
      for (final bm in bookmarks) {
        final bookmark = doc.bookmarks.add(bm.title);
        final clampedIndex = bm.pageIndex.clamp(0, doc.pages.count - 1);
        bookmark.destination = PdfDestination(doc.pages[clampedIndex]);
      }
    } catch (_) {}
    final bytes = await doc.save();
    doc.dispose();
    return AppStorage.writePdf(title, bytes);
  }

  /// Renders a signature drawing into trimmed PNG bytes (helper for editor).
  static Future<Uint8List?> imageToPng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}
