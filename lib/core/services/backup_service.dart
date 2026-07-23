import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Creates and restores full-app backups (documents, scans, PDFs, database)
/// as a single portable `.zip` (optionally AES-256-CBC encrypted) the user can
/// store anywhere (e.g. Drive).
class BackupService {
  static const _backupDirs = [
    'pages',
    'pdfs',
    'imports',
    'signatures',
  ];
  static const _dbFile = 'default.isar';

  // AES-256 constants
  static const _saltLength = 16;
  static const _ivLength = 16;
  static const _keyLength = 32; // 256 bits
  static const _pbkdf2Iterations = 100000;

  /// Bundles app data into a zip and returns its path.
  ///
  /// If [password] is non-null, the ZIP is encrypted with AES-256-CBC
  /// using PBKDF2-derived key and the file extension becomes `.enc`.
  static Future<String> createBackup({String? password}) async {
    final base = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final tmp = await getTemporaryDirectory();
    final ext = password != null ? 'enc' : 'zip';
    final zipPath = p.join(tmp.path, 'xscan_backup_$stamp.$ext');

    // Create unencrypted ZIP first
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

    if (password == null) return zipPath;

    // Encrypt the ZIP with AES-256-CBC
    final zipBytes = await File(zipPath).readAsBytes();
    final encryptedBytes = _encryptBytes(zipBytes, password);
    await File(zipPath).writeAsBytes(encryptedBytes);

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

    List<int> fileBytes = await File(zipPath).readAsBytes();

    // Detect encrypted file by extension
    if (zipPath.endsWith('.enc')) {
      if (password == null || password.isEmpty) {
        throw BackupException('Password required for encrypted backup');
      }
      fileBytes = _decryptBytes(fileBytes, password);
    }

    final archive = ZipDecoder().decodeBytes(fileBytes);

    for (final file in archive) {
      final filePath = p.canonicalize(p.join(basePath, file.name));

      // Zip-slip guard: the resolved path must be under the base directory.
      if (!filePath.startsWith(basePath)) {
        throw BackupException(
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

  // ---------------------------------------------------------------------------
  // AES-256-CBC encryption helpers
  // ---------------------------------------------------------------------------

  static Uint8List _encryptBytes(List<int> plainBytes, String password) {
    final salt = _randomBytes(_saltLength);
    final iv = encrypt.IV(_randomBytes(_ivLength));
    final key = _deriveKey(password, salt);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Format: [salt(16)][iv(16)][ciphertext]
    final result = Uint8List(_saltLength + _ivLength + encrypted.bytes.length);
    result.setRange(0, _saltLength, salt);
    result.setRange(_saltLength, _saltLength + _ivLength, iv.bytes);
    result.setRange(_saltLength + _ivLength, result.length, encrypted.bytes);
    return result;
  }

  static Uint8List _decryptBytes(List<int> cipherBytes, String password) {
    if (cipherBytes.length < _saltLength + _ivLength + 16) {
      throw BackupException('Encrypted backup is corrupted or too small');
    }

    final salt = Uint8List.fromList(cipherBytes.sublist(0, _saltLength));
    final iv = encrypt.IV(Uint8List.fromList(
      cipherBytes.sublist(_saltLength, _saltLength + _ivLength),
    ));
    final ciphertext = Uint8List.fromList(cipherBytes.sublist(_saltLength + _ivLength));

    final key = _deriveKey(password, salt);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(encrypt.Encrypted(ciphertext), iv: iv),
    );
  }

  static encrypt.Key _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final keyBytes = _pbkdf2(passwordBytes, salt, _pbkdf2Iterations, _keyLength);
    return encrypt.Key(keyBytes);
  }

  /// PBKDF2-HMAC-SHA256 key derivation.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength / 32).ceil();
    final result = Uint8List(keyLength);

    for (var block = 1; block <= blockCount; block++) {
      // U1 = HMAC(password, salt || INT(block))
      final blockBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, block, Endian.big);
      var u = hmac.convert([...salt, ...blockBytes]).bytes;

      var derived = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < 32; j++) {
          derived[j] ^= u[j];
        }
      }

      final offset = (block - 1) * 32;
      final length = (keyLength - offset).clamp(0, 32);
      result.setRange(offset, offset + length, derived.sublist(0, length));
    }

    return result;
  }

  static Uint8List _randomBytes(int length) {
    final secureRandom = encrypt.SecureRandom(length);
    return secureRandom.bytes;
  }
}

/// Exception thrown when a backup operation fails.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => 'BackupException: $message';
}
