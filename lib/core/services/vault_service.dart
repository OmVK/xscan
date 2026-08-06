import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'crypto_utils.dart';

/// Provides authenticated AES-256-GCM encryption for the hidden documents vault.
///
/// The vault key is generated once and stored in [FlutterSecureStorage].
/// Each file is encrypted with a random 12-byte nonce prepended to the
/// ciphertext; the 16-byte GCM authentication tag is appended by the cipher
/// so tampering is detected instead of silently corrupting plaintext.
class VaultService {
  static const _keyName = 'vault_aes_key';

  final FlutterSecureStorage _storage;

  VaultService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Returns the vault AES key, creating one if it doesn't exist.
  Future<Key> _getKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return Key.fromBase64(existing);
    }
    final key = Key.fromSecureRandom(32);
    await _storage.write(key: _keyName, value: key.base64);
    return key;
  }

  /// Whether the vault has been initialized (key exists).
  Future<bool> isInitialized() async {
    return await _storage.read(key: _keyName) != null;
  }

  /// Encrypts a file in-place, replacing the plaintext with encrypted data.
  /// Returns the file path (unchanged).
  Future<String> encryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return filePath;

    final key = await _getKey();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return filePath;

    // Format: [nonce(12)][ciphertext || gcm-tag]
    final output = aesGcmSeal(key, bytes);
    await file.writeAsBytes(output, flush: true);
    return filePath;
  }

  /// Decrypts an encrypted file in-place, returning it to plaintext.
  /// Returns the file path (unchanged).
  ///
  /// Throws [VaultException] if the ciphertext is corrupt, tampered with, or
  /// was produced by an older incompatible format — the caller must not
  /// overwrite the encrypted file in that case.
  Future<String> decryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return filePath;

    final key = await _getKey();
    final bytes = await file.readAsBytes();
    if (bytes.length <= aesGcmNonceLength + aesGcmTagLength) return filePath;

    final decrypted = _open(key, bytes);
    await file.writeAsBytes(decrypted, flush: true);
    return filePath;
  }

  /// Decrypts a file to a temporary location for viewing, without modifying
  /// the original. Returns the temp file path.
  ///
  /// The temp file is written into the app's private documents directory
  /// (never the shared system temp), is given a random name, and callers must
  /// remove it with [deleteTempFile] once the view is complete.
  Future<String> decryptToTemp(String filePath) async {
    final key = await _getKey();
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length <= aesGcmNonceLength + aesGcmTagLength) return filePath;

    final decrypted = _open(key, bytes);

    final tempDir = await _tempDir();
    final tempFile = File(
      p.join(
        tempDir.path,
        'vault_${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(decrypted, flush: true);
    return tempFile.path;
  }

  /// Deletes a temp file produced by [decryptToTemp].
  ///
  /// Refuses to touch anything that isn't a `.tmp` file under the vault temp
  /// directory, so an original (still-encrypted) document can never be
  /// accidentally deleted.
  static Future<void> deleteTempFile(String filePath) async {
    try {
      final path = p.normalize(filePath);
      if (!path.endsWith('.tmp')) return;

      final dir = await _tempDir();
      final inAppTemp = p.normalize(dir.path);
      if (p.isWithin(inAppTemp, path)) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup — nothing sensible to do if it fails.
    }
  }

  /// Removes leftover vault temp files from previous sessions.
  static Future<void> cleanupStaleTempFiles() async {
    try {
      final dir = await _tempDir();
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is File && entry.path.endsWith('.tmp')) {
          try {
            await entry.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Directory may not exist on first launch.
    }
  }

  /// Removes the vault key, permanently locking all encrypted files.
  Future<void> destroyKey() async {
    await _storage.delete(key: _keyName);
  }

  // ---------------------------------------------------------------------------
  // AES-256-GCM primitives (delegated to the pure crypto_utils module)
  // ---------------------------------------------------------------------------

  Uint8List _open(Key key, Uint8List envelope) {
    try {
      return aesGcmOpen(key, envelope);
    } on CryptoException catch (e) {
      throw VaultException(
        'Failed to decrypt vault file (wrong key, tampered, or legacy format). '
        'The file was NOT modified.',
        originalError: e.originalError,
      );
    }
  }

  static Future<Directory> _tempDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'tmp'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

/// Thrown when a vault operation fails (bad key, tampered ciphertext, …).
class VaultException implements Exception {
  VaultException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => 'VaultException: $message';
}