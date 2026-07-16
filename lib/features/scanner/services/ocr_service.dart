import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A recognized line of text with its bounding box (in source-image pixels).
class OcrLine {
  OcrLine(this.text, this.box);
  final String text;
  final ui.Rect box;
}

/// OCR result for a single image, including the image's pixel dimensions so
/// callers can map boxes onto a PDF page.
class OcrResult {
  OcrResult({
    required this.text,
    required this.lines,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String text;
  final List<OcrLine> lines;
  final int imageWidth;
  final int imageHeight;
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

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }

  /// Full structured recognition with per-line bounding boxes.
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

    return OcrResult(
      text: recognized.text,
      lines: lines,
      imageWidth: size.width.round(),
      imageHeight: size.height.round(),
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
