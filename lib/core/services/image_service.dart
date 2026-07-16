import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:xscan/core/services/app_storage.dart';

/// Color mode presets for the document scanner / image editor.
enum ImageColorMode { original, color, grayscale, blackWhite }

/// Named filters for the image editor.
enum ImageFilterType { none, magic, vivid, cool, warm, vintage, invert }

/// Adjustable parameters applied to an image, plus geometric operations.
class ImageEdit {
  ImageColorMode colorMode;
  ImageFilterType filter;

  /// -100..100
  int brightness;
  int contrast;
  int saturation;
  int sharpness;

  /// 0..100 gaussian blur radius scaled down internally.
  int blur;

  /// Rotation in degrees (0, 90, 180, 270 typical, but any allowed).
  int rotation;
  bool flipH;
  bool flipV;

  /// Optional resize (longest edge in px), null = keep original.
  int? maxEdge;

  ImageEdit({
    this.colorMode = ImageColorMode.original,
    this.filter = ImageFilterType.none,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.sharpness = 0,
    this.blur = 0,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.maxEdge,
  });
}

class ImageService {
  /// Decodes, applies [edit], and returns the processed image bytes as PNG.
  static Future<List<int>> processToPng(String path, ImageEdit edit) async {
    final image = await _decode(path);
    final processed = _apply(image, edit);
    return img.encodePng(processed);
  }

  /// Applies [edit] and persists the result as a page, returning its path.
  static Future<String> processAndSave(String path, ImageEdit edit) async {
    final image = await _decode(path);
    final processed = _apply(image, edit);
    final bytes = img.encodeJpg(processed, quality: 92);
    final tmp = File(
      '${Directory.systemTemp.path}/edit_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tmp.writeAsBytes(bytes, flush: true);
    return AppStorage.persistPage(tmp.path);
  }

  /// Auto document enhancement: normalize, boost contrast, sharpen — good for
  /// removing shadows/dull lighting on scanned pages.
  static ImageEdit autoEnhancePreset() => ImageEdit(
        colorMode: ImageColorMode.color,
        contrast: 25,
        brightness: 8,
        sharpness: 30,
        saturation: 8,
      );

  static Future<img.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unsupported or corrupt image: $path');
    }
    return decoded;
  }

  static img.Image _apply(img.Image src, ImageEdit e) {
    var image = img.Image.from(src);

    if (e.maxEdge != null) {
      final longest = math.max(image.width, image.height);
      if (longest > e.maxEdge!) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: e.maxEdge);
        } else {
          image = img.copyResize(image, height: e.maxEdge);
        }
      }
    }

    if (e.rotation % 360 != 0) {
      image = img.copyRotate(image, angle: e.rotation);
    }
    if (e.flipH) image = img.flipHorizontal(image);
    if (e.flipV) image = img.flipVertical(image);

    // Brightness / contrast / saturation adjustments.
    if (e.brightness != 0 || e.contrast != 0 || e.saturation != 0) {
      image = img.adjustColor(
        image,
        brightness: 1 + (e.brightness / 100),
        contrast: 1 + (e.contrast / 100),
        saturation: 1 + (e.saturation / 100),
      );
    }

    if (e.blur > 0) {
      image = img.gaussianBlur(image, radius: (e.blur / 10).ceil());
    }

    if (e.sharpness > 0) {
      final amount = e.sharpness / 100;
      final kernel = <num>[
        0, -amount, 0,
        -amount, 1 + 4 * amount, -amount,
        0, -amount, 0,
      ];
      image = img.convolution(image, filter: kernel);
    }

    switch (e.colorMode) {
      case ImageColorMode.grayscale:
        image = img.grayscale(image);
        break;
      case ImageColorMode.blackWhite:
        image = _threshold(img.grayscale(image));
        break;
      case ImageColorMode.color:
      case ImageColorMode.original:
        break;
    }

    switch (e.filter) {
      case ImageFilterType.magic:
        image = img.adjustColor(image, contrast: 1.3, saturation: 1.2);
        image = img.convolution(image, filter: const [
          0, -0.3, 0,
          -0.3, 2.2, -0.3,
          0, -0.3, 0,
        ]);
        break;
      case ImageFilterType.vivid:
        image = img.adjustColor(image, saturation: 1.5, contrast: 1.15);
        break;
      case ImageFilterType.cool:
        image = img.adjustColor(image, saturation: 1.05);
        image = img.colorOffset(image, blue: 25, red: -10);
        break;
      case ImageFilterType.warm:
        image = img.colorOffset(image, red: 25, blue: -15);
        break;
      case ImageFilterType.vintage:
        image = img.sepia(image);
        break;
      case ImageFilterType.invert:
        image = img.invert(image);
        break;
      case ImageFilterType.none:
        break;
    }

    return image;
  }

  /// Adaptive-ish threshold for crisp black & white scans.
  static img.Image _threshold(img.Image gray) {
    // Compute mean luminance.
    var sum = 0;
    var count = 0;
    for (final p in gray) {
      sum += p.r.toInt();
      count++;
    }
    final mean = count == 0 ? 128 : (sum / count).round();
    final t = (mean * 0.92).clamp(60, 200).toInt();
    for (final p in gray) {
      final v = p.r >= t ? 255 : 0;
      p.setRgb(v, v, v);
    }
    return gray;
  }

  /// Converts an image file to another format. Returns exported file path.
  static Future<String> convertFormat(String path, String format) async {
    final image = await _decode(path);
    List<int> bytes;
    String ext;
    switch (format.toLowerCase()) {
      case 'png':
        bytes = img.encodePng(image);
        ext = 'png';
        break;
      case 'jpg':
      case 'jpeg':
        bytes = img.encodeJpg(image, quality: 92);
        ext = 'jpg';
        break;
      case 'webp':
        // image package has limited webp encode; fall back to png bytes.
        bytes = img.encodePng(image);
        ext = 'png';
        break;
      case 'tiff':
        bytes = img.encodeTiff(image);
        ext = 'tiff';
        break;
      case 'bmp':
        bytes = img.encodeBmp(image);
        ext = 'bmp';
        break;
      default:
        bytes = img.encodePng(image);
        ext = 'png';
    }
    final name = 'converted.$ext';
    return AppStorage.writeExport(name, bytes);
  }
}
