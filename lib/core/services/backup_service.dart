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
  static Future<void> restoreBackup(String zipPath) async {
    final base = await getApplicationDocumentsDirectory();
    await extractFileToDisk(zipPath, base.path);
  }
}
