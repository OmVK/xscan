import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'crypto_utils.dart';
import 'path_safety.dart';

/// Creates and restores full-app backups (documents, scans, PDFs, database)
/// as a single portable `.zip` (optionally AES-256-GCM authenticated
/// encryption) the user can store anywhere (e.g. Drive).
///
/// All heavy work (zip packing, PBKDF2 key derivation, AES) runs on a
/// background isolate so the UI never freezes while backing up.
class BackupService {
  static const _backupDirs = [
    'pages',
    'pdfs',
    'imports',
    'signatures',
  ];
  static const _dbFile = 'default.isar';

  /// Bundles app data into a zip and returns its path.
  ///
  /// If [password] is non-null, the ZIP is encrypted with AES-256-GCM
  /// using a PBKDF2-derived key and the file extension becomes `.enc`.
  static Future<String> createBackup({String? password}) async {
    final base = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final ext = password != null ? 'enc' : 'zip';
    final zipPath = p.join(tmp.path, 'xscan_backup_$stamp.$ext');

    final basePath = base.path;
    final dirs = _backupDirs;
    final dbPath = p.join(basePath, _dbFile);

    try {
      await Isolate.run(() async {
        // Create unencrypted ZIP first.
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        try {
          for (final name in dirs) {
            final dir = Directory(p.join(basePath, name));
            if (dir.existsSync()) {
              await encoder.addDirectory(dir);
            }
          }
          if (File(dbPath).existsSync()) {
            await encoder.addFile(dbPath);
          }
        } finally {
          await encoder.close();
        }

        // Optionally encrypt the ZIP with AES-256-GCM.
        if (password != null) {
          final zipBytes = File(zipPath).readAsBytesSync();
          File(zipPath).writeAsBytesSync(
            sealWithPassword(zipBytes, password),
            flush: true,
          );
        }
      });
    } catch (e) {
      throw BackupException('Failed to create backup: $e');
    }

    return zipPath;
  }

  /// Restores a backup zip/enc into the app documents directory, overwriting
  /// existing data. The app should be restarted afterwards.
  ///
  /// Validates all file paths to prevent zip-slip (path traversal) attacks.
  /// If the file is encrypted (`.enc`), prompts for [password].
  static Future<void> restoreBackup(String zipPath, {String? password}) async {
    final base = await getApplicationDocumentsDirectory();
    final basePath = p.canonicalize(base.path);

    try {
      await Isolate.run(() {
        List<int> fileBytes = File(zipPath).readAsBytesSync();

        // Detect encrypted file by extension.
        if (zipPath.endsWith('.enc')) {
          if (password == null || password.isEmpty) {
            throw BackupException('Password required for encrypted backup');
          }
          try {
            fileBytes = openWithPassword(
              Uint8List.fromList(fileBytes),
              password,
            );
          } on CryptoException {
            throw BackupException(
              'Wrong password or tampered backup. '
              'The backup file was NOT modified.',
            );
          }
        }

        final archive = ZipDecoder().decodeBytes(fileBytes);

        for (final file in archive) {
          // Zip-slip guard: the resolved path must be strictly inside the
          // base directory (a sibling with a shared prefix must not pass).
          if (!zipEntryIsSafe(basePath, file.name)) {
            throw BackupException(
              'Backup contains path traversal: ${file.name}',
            );
          }
          final filePath = p.canonicalize(p.join(basePath, file.name));

          if (file.isFile) {
            final outDir = Directory(p.dirname(filePath));
            if (!outDir.existsSync()) {
              outDir.createSync(recursive: true);
            }
            File(filePath).writeAsBytesSync(
              file.content as List<int>,
              flush: true,
            );
          } else {
            final dir = Directory(filePath);
            if (!dir.existsSync()) {
              dir.createSync(recursive: true);
            }
          }
        }
      });
    } catch (e) {
      if (e is BackupException) rethrow;
      throw BackupException('Failed to restore backup: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Encryption helpers (delegated to the pure crypto_utils module)
  // ---------------------------------------------------------------------------
}

/// Exception thrown when a backup operation fails.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => 'BackupException: $message';
}