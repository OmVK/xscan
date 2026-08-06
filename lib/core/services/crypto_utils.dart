import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Pure-Dart AES-256-GCM + PBKDF2 helpers shared by `vault_service` and
/// `backup_service`.
///
/// This file has **no platform-plugin imports**, so every function here is
/// unit-testable on the plain Dart VM (`flutter test` without a device).
///
/// File formats (all little endian, simple concatenated byte arrays):
/// * Vault:  `nonce(12) || ciphertext || gcm-tag(16)`
/// * Backup:  `salt(16) || nonce(12) || ciphertext || gcm-tag(16)`

const int aesGcmNonceLength = 12;
const int aesGcmTagLength = 16;

const int pbkdf2SaltLength = 16;
const int pbkdf2Iterations = 100000;
const int aesKeyLength = 32; // 256-bit key

/// Thrown when an authenticated-decryption step fails (bad key, tampered data,
/// malformed envelope). The ciphertext was not modified in this case.
class CryptoException implements Exception {
  CryptoException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => 'CryptoException: $message';
}

/// Encrypts [plaintext] and returns `nonce(12) || ciphertext || gcm-tag(16)`.
///
/// The GCM authentication tag is produced by the cipher, so the returned
/// blob cannot be silently altered without [aesGcmOpen] rejecting it.
Uint8List aesGcmSeal(Key key, List<int> plaintext) {
  final nonce = IV.fromSecureRandom(aesGcmNonceLength);
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  // For GCM the cipher returns ciphertext with the 16-byte tag appended.
  final sealed = encrypter.encryptBytes(plaintext, iv: nonce);

  final output = Uint8List(aesGcmNonceLength + sealed.bytes.length);
  output.setRange(0, aesGcmNonceLength, nonce.bytes);
  output.setRange(aesGcmNonceLength, output.length, sealed.bytes);
  return output;
}

/// Authenticicates + decrypts an envelope produced by [aesGcmSeal].
///
/// Throws [CryptoException] on malformed input, wrong key, or tampering.
Uint8List aesGcmOpen(Key key, Uint8List envelope) {
  if (envelope.length < aesGcmNonceLength + aesGcmTagLength) {
    throw CryptoException('Ciphertext too short to be a valid GCM envelope');
  }
  try {
    final nonce = IV(envelope.sublist(0, aesGcmNonceLength));
    final sealed = Encrypted(envelope.sublist(aesGcmNonceLength));
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    return encrypter.decryptBytes(sealed, iv: nonce);
  } catch (e) {
    throw CryptoException('GCM authentication failed', originalError: e);
  }
}

/// Derives a 256-bit key via PBKDF2-HMAC-SHA256.
Uint8List deriveKeyFromPassword(String password, Uint8List salt) {
  return pbkdf2HmacSha256(
    utf8.encode(password),
    salt,
    pbkdf2Iterations,
    aesKeyLength,
  );
}

/// Encrypts [plaintext] with a password-derived AES-256-GCM key and returns
/// `salt(16) || nonce(12) || ciphertext || gcm-tag(16)`.
Uint8List sealWithPassword(List<int> plaintext, String password) {
  final salt = _randomBytes(pbkdf2SaltLength);
  final key = Key(deriveKeyFromPassword(password, salt));
  final sealed = aesGcmSeal(key, plaintext);

  final output = Uint8List(salt.length + sealed.length);
  output.setRange(0, salt.length, salt);
  output.setRange(salt.length, output.length, sealed);
  return output;
}

/// Verifies and decrypts a password-encrypted backup envelope.
///
/// Throws [CryptoException] on a wrong password or tampered data.
Uint8List openWithPassword(Uint8List envelope, String password) {
  if (envelope.length < pbkdf2SaltLength + aesGcmNonceLength + aesGcmTagLength) {
    throw CryptoException('Encrypted backup is corrupted or too small');
  }
  final salt = Uint8List.sublistView(envelope, 0, pbkdf2SaltLength);
  final key = Key(deriveKeyFromPassword(password, salt));
  try {
    final sealed = Uint8List.sublistView(envelope, pbkdf2SaltLength);
    return aesGcmOpen(key, sealed);
  } on CryptoException catch (e) {
    throw CryptoException('Wrong password or tampered backup', originalError: e);
  }
}

/// PBKDF2-HMAC-SHA256 (RFC 2898) key derivation.
Uint8List pbkdf2HmacSha256(
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

Uint8List _randomBytes([int length = pbkdf2SaltLength]) {
  final secureRandom = SecureRandom(length);
  return secureRandom.bytes;
}