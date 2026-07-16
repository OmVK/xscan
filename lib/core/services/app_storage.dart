import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Central helper for the app's permanent, private storage.
///
/// Files produced by scanning or the PDF tools are copied here so they survive
/// OS cache cleanup (image_picker / image_cropper write to temp dirs).
class AppStorage {
  static const _pagesDir = 'pages';
  static const _pdfDir = 'pdfs';
  static const _exportDir = 'exports';
  static const _signatureDir = 'signatures';

  static Future<Directory> _subDir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a scanned page image into permanent storage and returns the new path.
  static Future<String> persistPage(String sourcePath) async {
    final dir = await _subDir(_pagesDir);
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath)
        : '.jpg';
    final name = 'page_${DateTime.now().microsecondsSinceEpoch}$ext';
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Returns a unique output path inside the pdf directory for [title].
  static Future<String> pdfOutputPath(String title) async {
    final dir = await _subDir(_pdfDir);
    final safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${safe}_$stamp.pdf');
  }

  /// Writes [bytes] to a new pdf file named after [title] and returns the path.
  static Future<String> writePdf(String title, List<int> bytes) async {
    final path = await pdfOutputPath(title);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Writes an exported artifact (image/text) and returns its path.
  static Future<String> writeExport(String name, List<int> bytes) async {
    final dir = await _subDir(_exportDir);
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._]+'), '_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = p.join(dir.path, '${stamp}_$safe');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Persists a signature/stamp PNG and returns its permanent path.
  static Future<String> saveSignature(List<int> bytes) async {
    final dir = await _subDir(_signatureDir);
    final name = 'sig_${DateTime.now().microsecondsSinceEpoch}.png';
    final path = p.join(dir.path, name);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Lists saved signature/stamp files (newest first).
  static Future<List<String>> listSignatures() async {
    final dir = await _subDir(_signatureDir);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => f.path).toList();
  }

  static Future<void> deleteSignature(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
