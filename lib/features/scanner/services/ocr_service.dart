import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

/// A recognized line of text with its bounding box (in source-image pixels).
class OcrLine {
  OcrLine(this.text, this.box);
  final String text;
  final ui.Rect box;
}

/// OCR result for a single image, including the image's pixel dimensions.
class OcrResult {
  OcrResult({
    required this.text,
    required this.lines,
    required this.imageWidth,
    required this.imageHeight,
    required this.entities,
  });

  final String text;
  final List<OcrLine> lines;
  final int imageWidth;
  final int imageHeight;
  final OcrEntities entities;
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

  Future<ui.Size> _imageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    frame.image.dispose();
    return ui.Size(w, h);
  }

  void dispose() {
    textRecognizer.close();
  }
}
