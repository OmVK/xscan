import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles importing files from device storage or other apps.
class FileImportService {
  static const _importDir = 'imports';

  /// Opens the system file browser for a single PDF and copies it into the
  /// app's import storage. Returns the local path, or null if cancelled.
  static Future<String?> pickPdf() async {
    const group = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    return _copyIntoStorage(file.path, fallbackExt: '.pdf');
  }

  /// Opens the system file browser for one or more images.
  static Future<List<String>> pickImages() async {
    const group = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      mimeTypes: ['image/*'],
    );
    final files = await openFiles(acceptedTypeGroups: [group]);
    final result = <String>[];
    for (final f in files) {
      result.add(await _copyIntoStorage(f.path, fallbackExt: '.jpg'));
    }
    return result;
  }

  /// Copies an externally supplied file into permanent import storage so it
  /// survives after the source (content:// / cache) goes away.
  static Future<String> copyIntoStorage(String sourcePath) =>
      _copyIntoStorage(sourcePath, fallbackExt: p.extension(sourcePath));

  static Future<String> _copyIntoStorage(
    String sourcePath, {
    required String fallbackExt,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _importDir));
    if (!await dir.exists()) await dir.create(recursive: true);

    var name = p.basename(sourcePath);
    if (p.extension(name).isEmpty) {
      name = 'file_${DateTime.now().microsecondsSinceEpoch}$fallbackExt';
    } else {
      name = '${DateTime.now().microsecondsSinceEpoch}_$name';
    }
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }
}
