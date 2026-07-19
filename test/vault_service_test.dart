import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/services/vault_service.dart';

/// These tests require a real device/emulator for flutter_secure_storage.
/// They are skipped in `flutter test` (unit test) mode and should be run
/// via `flutter test --platform android` or as integration tests.
void main() {
  late Directory tempDir;
  late VaultService vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vault_test_');
    vault = VaultService();
  });

  tearDown(() async {
    try {
      await vault.destroyKey();
    } catch (_) {}
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VaultService', () {
    test('encrypts and decrypts a file', () async {
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsBytes([72, 101, 108, 108, 111]); // "Hello"

      await vault.encryptFile(file.path);

      final encrypted = await file.readAsBytes();
      // Encrypted data should be different from original.
      expect(encrypted, isNot([72, 101, 108, 108, 111]));

      await vault.decryptFile(file.path);

      final decrypted = await file.readAsBytes();
      expect(decrypted, [72, 101, 108, 108, 111]);
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('decryptToTemp returns decrypted copy without modifying original',
        () async {
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsBytes([1, 2, 3, 4, 5]);

      await vault.encryptFile(file.path);

      final tempPath = await vault.decryptToTemp(file.path);
      addTearDown(() async {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) await tempFile.delete();
      });

      final tempFile = File(tempPath);
      expect(await tempFile.readAsBytes(), [1, 2, 3, 4, 5]);

      // Original should still be encrypted.
      final stillEncrypted = await file.readAsBytes();
      expect(stillEncrypted, isNot([1, 2, 3, 4, 5]));
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('isInitialized returns false before key creation', () async {
      expect(await vault.isInitialized(), isFalse);
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('isInitialized returns true after key creation', () async {
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsBytes([10, 20, 30]);
      await vault.encryptFile(file.path);
      expect(await vault.isInitialized(), isTrue);
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('destroyKey prevents further decryption', () async {
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsBytes([100, 200]);
      await vault.encryptFile(file.path);
      await vault.destroyKey();

      expect(
        () => vault.decryptFile(file.path),
        throwsA(anything),
      );
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('encrypting empty file is a no-op', () async {
      final file = File('${tempDir.path}/empty.txt');
      await file.writeAsBytes([]);

      await vault.encryptFile(file.path);

      final bytes = await file.readAsBytes();
      expect(bytes, isEmpty);
    }, skip: 'Requires flutter_secure_storage platform plugin');

    test('encrypting non-existent file returns path unchanged', () async {
      final result = await vault.encryptFile('${tempDir.path}/nope.txt');
      expect(result, '${tempDir.path}/nope.txt');
    }, skip: 'Requires flutter_secure_storage platform plugin');
  });
}
