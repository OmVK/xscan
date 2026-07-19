import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Creates and restores full-app backups (documents, scans, PDFs, database)
/// as a single portable `.zip` the user can store anywhere (e.g. Drive).
class BackupService {
  static const _backupDirs = [
    'pages',
    'pdfs',
    'imports',
    'signatures',
  ];
  static const _dbFile = 'default.isar';

  /// Bundles app data into a zip and returns its path.
  static Future<String> createBackup() async {
    final base = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final tmp = await getTemporaryDirectory();
    final zipPath = p.join(tmp.path, 'xscan_backup_$stamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    try {
      for (final name in _backupDirs) {
        final dir = Directory(p.join(base.path, name));
        if (await dir.exists()) {
          await encoder.addDirectory(dir);
        }
      }
      final db = File(p.join(base.path, _dbFile));
      if (await db.exists()) {
        await encoder.addFile(db);
      }
    } finally {
      await encoder.close();
    }
    return zipPath;
  }

  /// Restores a backup zip into the app documents directory, overwriting
  /// existing data. The app should be restarted afterwards.
  ///
  /// Validates all file paths to prevent zip-slip (path traversal) attacks.
  static Future<void> restoreBackup(String zipPath) async {
    final base = await getApplicationDocumentsDirectory();
    final basePath = p.canonicalize(base.path);

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = p.canonicalize(p.join(basePath, file.name));

      // Zip-slip guard: the resolved path must be under the base directory.
      if (!filePath.startsWith(basePath)) {
        throw SecurityException(
          'Backup contains path traversal: ${file.name}',
        );
      }

      if (file.isFile) {
        final outDir = Directory(p.dirname(filePath));
        if (!await outDir.exists()) {
          await outDir.create(recursive: true);
        }
        final output = File(filePath);
        await output.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        final dir = Directory(filePath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    }
  }
}

/// Exception thrown when a security violation is detected during backup restore.
class SecurityException implements Exception {
  SecurityException(this.message);
  final String message;

  @override
  String toString() => 'SecurityException: $message';
}
