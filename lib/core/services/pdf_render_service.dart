import 'dart:typed_data';

import 'package:pdfx/pdfx.dart' as pdfx;

import 'package:xscan/core/services/app_storage.dart';

/// A rendered raster of a single PDF page plus its logical (point) size.
class RenderedPage {
  RenderedPage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;

  /// Logical page size in PDF points (aspect ratio source).
  final double width;
  final double height;

  double get aspectRatio => height == 0 ? 1 : width / height;
}

/// Rasterizes PDF pages to PNG images using the platform renderer.
class PdfRenderService {
  /// Renders one page (0-based [pageIndex]) at the given pixel [scale].
  Future<RenderedPage?> renderPage(
    String path,
    int pageIndex, {
    double scale = 2.0,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    try {
      final page = await doc.getPage(pageIndex + 1);
      try {
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (image == null) return null;
        return RenderedPage(
          bytes: image.bytes,
          width: page.width,
          height: page.height,
        );
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
  }

  /// Renders every page (used for thumbnails / page manager).
  Future<List<RenderedPage>> renderAll(
    String path, {
    double scale = 1.0,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    final pages = <RenderedPage>[];
    try {
      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        try {
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) {
            pages.add(RenderedPage(
              bytes: image.bytes,
              width: page.width,
              height: page.height,
            ));
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await doc.close();
    }
    return pages;
  }

  /// Renders every page to a PNG file in export storage and returns the paths.
  Future<List<String>> renderAllToFiles(
    String path, {
    double scale = 2.0,
    void Function(int done, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    final paths = <String>[];
    try {
      final total = doc.pagesCount;
      for (var i = 1; i <= total; i++) {
        final page = await doc.getPage(i);
        try {
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) {
            paths.add(await AppStorage.writeExport('page_$i.png', image.bytes));
          }
        } finally {
          await page.close();
        }
        onProgress?.call(i, total);
      }
    } finally {
      await doc.close();
    }
    return paths;
  }
}
