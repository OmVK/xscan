import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/services/crypto_utils.dart';

void main() {
  Key testKey() => Key.fromSecureRandom(32);

  group('aesGcmSeal / aesGcmOpen', () {
    test('round-trips plaintext of a range of sizes', () {
      final key = testKey();
      for (final size in [0, 1, 15, 16, 17, 31, 32, 33, 1024, 65536]) {
        final data = Uint8List(size);
        for (var i = 0; i < size; i++) {
          data[i] = (i * 7) % 256;
        }

        final sealed = aesGcmSeal(key, data);

        // nonce(12) + ciphertext + gcm-tag(16)
        expect(sealed.length, size + aesGcmNonceLength + aesGcmTagLength);

        final opened = aesGcmOpen(key, sealed);
        expect(opened, equals(data));
      }
    });

    test('uses a fresh nonce for every seal (no key nonce reuse)', () {
      final key = testKey();
      final first = aesGcmSeal(key, ascii.encode('hello'));
      final second = aesGcmSeal(key, ascii.encode('hello'));
      expect(first, isNot(equals(second)));
    });

    test('detects a single flipped byte in ciphertext', () {
      final key = testKey();
      final sealed = aesGcmSeal(key, utf8.encode('vault secret payload'));
      final tampered = Uint8List.fromList(sealed);
      tampered[aesGcmNonceLength + 3] ^= 0x01;

      expect(
        () => aesGcmOpen(key, tampered),
        throwsA(isA<CryptoException>()),
      );
    });

    test('detects a single flipped byte in the nonce', () {
      final key = testKey();
      final sealed = aesGcmSeal(key, utf8.encode('vault secret payload'));
      final tampered = Uint8List.fromList(sealed);
      tampered[0] ^= 0x01;

      expect(
        () => aesGcmOpen(key, tampered),
        throwsA(isA<CryptoException>()),
      );
    });

    test('rejects a wrong key', () {
      final sealed = aesGcmSeal(testKey(), utf8.encode('only one key works'));
      expect(
        () => aesGcmOpen(testKey(), sealed),
        throwsA(isA<CryptoException>()),
      );
    });

    test('rejects an envelope too short to contain the tag', () {
      final key = testKey();
      final short = Uint8List(aesGcmNonceLength + aesGcmTagLength - 1);
      for (var i = 0; i < short.length; i++) {
        short[i] = (i * 13) % 256;
      }
      expect(() => aesGcmOpen(key, short), throwsA(isA<CryptoException>()));
    });
  });

  group('sealWithPassword / openWithPassword (backup format)', () {
    test('round-trips with a password', () {
      const password = 'correct horse battery staple';
      final plaintext = utf8.encode('my carefully typed zip bytes');
      final sealed = sealWithPassword(plaintext, password);

      expect(
        sealed.length,
        plaintext.length + pbkdf2SaltLength + aesGcmNonceLength + aesGcmTagLength,
      );

      final opened = openWithPassword(sealed, password);
      expect(utf8.decode(opened), 'my carefully typed zip bytes');
    });

    test('rejects the wrong password', () {
      final sealed = sealWithPassword(
        utf8.encode('secret'),
        'right-password',
      );
      expect(
        () => openWithPassword(sealed, 'wrong-password'),
        throwsA(isA<CryptoException>()),
      );
    });

    test('each seal uses a fresh salt (no password ciphertext reuse)', () {
      const plaintext = 'same data';
      const password = 'pw';
      final first = sealWithPassword(ascii.encode(plaintext), password);
      final second = sealWithPassword(ascii.encode(plaintext), password);
      expect(first, isNot(equals(second)));
    });

    test('rejects a corrupted/short envelope', () {
      expect(
        () => openWithPassword(
          Uint8List(10),
          'whatever',
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('pbkdf2HmacSha256 (reference vectors)', () {
    test('matches the RFC-style single-iteration vector', () {
      final derived = pbkdf2HmacSha256(
        utf8.encode('password'),
        utf8.encode('salt'),
        1,
        32,
      );

      expect(
        derived,
        equals(
          _hex(
            '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
          ),
        ),
      );
    });

    test('multi-block derivation (48 bytes > one 32-byte block) matches', () {
      final derived = pbkdf2HmacSha256(
        utf8.encode('correct horse battery staple'),
        utf8.encode('xscan backup salt'),
        250,
        48,
      );
      expect(
        derived,
        equals(
          _hex(
            'b500a3927b8467dae8fd50960a86c956a68daea204bdd25e83652c3dc2670e1c73fe58c9c535c02a524f4c809103957c',
          ),
        ),
      );
    });

    test('is deterministic for identical inputs', () {
      final a = pbkdf2HmacSha256(utf8.encode('pw'), utf8.encode('s'), 10, 32);
      final b = pbkdf2HmacSha256(utf8.encode('pw'), utf8.encode('s'), 10, 32);
      expect(a, equals(b));
    });
  });

  group('deriveKeyFromPassword', () {
    test('derives a 32-byte AES-256 key usable with the encrypt package', () {
      final salt = Uint8List.fromList(utf8.encode('0123456789abcdef'));
      final keyBytes = deriveKeyFromPassword('hunter2', salt);
      expect(keyBytes.length, aesKeyLength);

      // Proves the derived bytes are a working AES-256 key end-to-end.
      final key = Key(keyBytes);
      final sealed = aesGcmSeal(key, utf8.encode('data'));
      expect(utf8.decode(aesGcmOpen(key, sealed)), 'data');
    });
  });
}

Uint8List _hex(String hex) {
  final cleaned = hex.replaceAll(RegExp(r'\s'), '');
  final bytes = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}