import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Extracted structured entities from OCR text.
class OcrEntities {
  final List<String> emails;
  final List<String> phones;
  final List<String> urls;
  final List<String> dates;
  final List<String> amounts;

  OcrEntities({
    required this.emails,
    required this.phones,
    required this.urls,
    required this.dates,
    required this.amounts,
  });

  bool get isEmpty =>
      emails.isEmpty &&
      phones.isEmpty &&
      urls.isEmpty &&
      dates.isEmpty &&
      amounts.isEmpty;
}

enum OcrLineKind { text, checkbox, bullet, star }

/// A recognized line of text with smart symbol detection, bounding box, and edit state.
class OcrLine {
  OcrLine(
    this.text,
    this.box, {
    String? editedText,
    this.isWhiteout = true,
    this.textColor = const ui.Color(0xFF1F2937),
    this.backgroundColor = const ui.Color(0xFFFFFFFF),
    this.fontSize,
    OcrLineKind? initialKind,
    bool? initialChecked,
  })  : currentText = editedText ?? text,
        kind = initialKind ?? _detectKind(editedText ?? text),
        isChecked = initialChecked ?? _detectChecked(editedText ?? text);

  /// Helper factory for adding user-created custom text boxes anywhere on the canvas
  factory OcrLine.newText(String text, {required double x, required double y}) {
    final box = ui.Rect.fromLTWH(x, y, 200, 36);
    return OcrLine(
      text,
      box,
      isWhiteout: true,
      textColor: const ui.Color(0xFF1F2937),
      backgroundColor: const ui.Color(0xFFFFFFFF),
    )..customLeft = x
     ..customTop = y;
  }

  final String text;
  String currentText;
  final ui.Rect box;
  bool isWhiteout;
  ui.Color textColor;
  ui.Color backgroundColor;
  double? fontSize;
  OcrLineKind kind;
  bool isChecked;

  double? customLeft;
  double? customTop;
  double? customWidth;
  double? customHeight;

  double get effectiveLeft => customLeft ?? box.left;
  double get effectiveTop => customTop ?? box.top;
  double get effectiveWidth => customWidth ?? box.width;
  double get effectiveHeight => customHeight ?? box.height;

  bool get isEdited =>
      currentText != text ||
      customLeft != null ||
      customTop != null ||
      customWidth != null ||
      customHeight != null;

  void resetPosition() {
    customLeft = null;
    customTop = null;
    customWidth = null;
    customHeight = null;
  }

  static OcrLineKind _detectKind(String str) {
    final t = str.trim();
    if (RegExp(r'^(\[[\sxXvV]\]|[\u2610\u2611\u2612\u25A0\u25A1]|\([\sxX]\))').hasMatch(t)) {
      return OcrLineKind.checkbox;
    }
    if (RegExp(r'^([\u2022\u25CF\u25CB\u25A0\*]|\d+[\.\)]|[a-zA-Z][\.\)])').hasMatch(t)) {
      return OcrLineKind.bullet;
    }
    if (RegExp(r'[\u2605\u2606]').hasMatch(t)) {
      return OcrLineKind.star;
    }
    return OcrLineKind.text;
  }

  static bool _detectChecked(String str) {
    final t = str.trim();
    return RegExp(r'^(\[[xXvV]\]|\u2611|\([xX]\))').hasMatch(t);
  }

  void toggleCheckbox() {
    if (kind != OcrLineKind.checkbox) {
      kind = OcrLineKind.checkbox;
    }
    isChecked = !isChecked;
    final prefix = isChecked ? '[x] ' : '[ ] ';
    final clean = currentText.replaceAll(RegExp(r'^(\[[\sxXvV]\]|[\u2610\u2611\u2612\u25A0\u25A1]|\([\sxX]\))\s*'), '');
    currentText = '$prefix$clean';
  }
}

/// OCR result for a single image, including the image's pixel dimensions and file path.
class OcrResult {
  OcrResult({
    required this.text,
    required this.lines,
    required this.imageWidth,
    required this.imageHeight,
    required this.entities,
    this.imagePath,
  });

  String text;
  final List<OcrLine> lines;
  final int imageWidth;
  final int imageHeight;
  final OcrEntities entities;
  final String? imagePath;

  /// Returns full text dynamically reconstructed from current (edited) lines.
  String get fullEditedText => lines.map((l) => l.currentText).join('\n');
}

class OcrService {
  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
      : textRecognizer = TextRecognizer(script: script);

  final TextRecognizer textRecognizer;

  /// Available OCR scripts for the UI.
  static const Map<String, TextRecognitionScript> scripts = {
    'Latin': TextRecognitionScript.latin,
    'Chinese': TextRecognitionScript.chinese,
    'Devanagari': TextRecognitionScript.devanagiri,
    'Japanese': TextRecognitionScript.japanese,
    'Korean': TextRecognitionScript.korean,
  };

  /// Returns extracted text from an image file.
  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return null;
    }
  }

  /// Full structured recognition with per-line bounding boxes and entity extraction.
  Future<OcrResult> extractStructured(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await textRecognizer.processImage(inputImage);
    final size = await _imageSize(imagePath);

    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (line.text.trim().isEmpty) continue;
        lines.add(OcrLine(line.text, line.boundingBox));
      }
    }

    final entities = parseEntities(recognized.text);

    return OcrResult(
      text: recognized.text,
      lines: lines,
      imageWidth: size.width.round(),
      imageHeight: size.height.round(),
      entities: entities,
      imagePath: imagePath,
    );
  }

  /// Regex-based structured entity extraction.
  static OcrEntities parseEntities(String fullText) {
    final emailRegex = RegExp(
        r'[a-zA-Z0-9.\_%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        caseSensitive: false);
    final phoneRegex = RegExp(
        r'(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}');
    final urlRegex = RegExp(
        r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
        caseSensitive: false);
    final dateRegex = RegExp(
        r'\b(\d{1,2}[\/\.-]\d{1,2}[\/\.-]\d{2,4}|\d{4}[\/\.-]\d{1,2}[\/\.-]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4})\b',
        caseSensitive: false);
    final amountRegex = RegExp(
        r'(\$|€|£|¥|SAR|AED|USD|EUR)\s?\d+(?:[.,]\d{2})?|\b\d+(?:[.,]\d{2})?\s?(SAR|AED|USD|EUR)\b');

    final emails = emailRegex
        .allMatches(fullText)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final phones = phoneRegex
        .allMatches(fullText)
        .map((m) => m.group(0)!)
        .where((p) => p.replaceAll(RegExp(r'\D'), '').length >= 7)
        .toSet()
        .toList();
    final urls = urlRegex
        .allMatches(fullText)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final dates = dateRegex
        .allMatches(fullText)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final amounts = amountRegex
        .allMatches(fullText)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    return OcrEntities(
      emails: emails,
      phones: phones,
      urls: urls,
      dates: dates,
      amounts: amounts,
    );
  }

  /// Decodes image dimensions on a background isolate so a full-resolution
  /// decode never blocks the UI thread.
  Future<ui.Size> _imageSize(String path) async {
    final dims = await Isolate.run(() {
      final bytes = File(path).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return (width: decoded.width, height: decoded.height);
    });
    if (dims == null) return ui.Size.zero;
    return ui.Size(dims.width.toDouble(), dims.height.toDouble());
  }

  void dispose() {
    textRecognizer.close();
  }
}
