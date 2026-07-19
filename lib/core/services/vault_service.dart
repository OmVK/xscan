import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides AES-256-CBC encryption for the hidden documents vault.
///
/// The vault key is generated once and stored in [FlutterSecureStorage].
/// Each file is encrypted with a random IV prepended to the ciphertext.
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

    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    // Format: 16-byte IV + encrypted data
    final output = Uint8List(16 + encrypted.bytes.length);
    output.setRange(0, 16, iv.bytes);
    output.setRange(16, output.length, encrypted.bytes);

    await file.writeAsBytes(output, flush: true);
    return filePath;
  }

  /// Decrypts an encrypted file in-place, returning it to plaintext.
  /// Returns the file path (unchanged).
  Future<String> decryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return filePath;

    final key = await _getKey();
    final bytes = await file.readAsBytes();
    if (bytes.length <= 16) return filePath;

    final iv = IV(bytes.sublist(0, 16));
    final encrypted = Encrypted(bytes.sublist(16));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

    await file.writeAsBytes(decrypted, flush: true);
    return filePath;
  }

  /// Decrypts a file to a temporary location for viewing, without modifying
  /// the original. Returns the temp file path.
  Future<String> decryptToTemp(String filePath) async {
    final key = await _getKey();
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length <= 16) return filePath;

    final iv = IV(bytes.sublist(0, 16));
    final encrypted = Encrypted(bytes.sublist(16));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

    final tempDir = Directory.systemTemp;
    final tempFile = File(
        '${tempDir.path}/vault_${DateTime.now().microsecondsSinceEpoch}.tmp');
    await tempFile.writeAsBytes(decrypted, flush: true);
    return tempFile.path;
  }

  /// Removes the vault key, permanently locking all encrypted files.
  Future<void> destroyKey() async {
    await _storage.delete(key: _keyName);
  }
}
