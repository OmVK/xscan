import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/services/backup_service.dart';

/// These tests require path_provider platform plugin.
/// They should be run via integration tests on a real device/emulator.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupService zip-slip protection', () {
    test('rejects zip with path traversal entries', () async {
      final maliciousZip = File('${tempDir.path}/malicious.zip');
      final archive = Archive();
      archive.addFile(ArchiveFile(
        '../../../etc/passwd',
        5,
        [1, 2, 3, 4, 5],
      ));
      final bytes = ZipEncoder().encode(archive);
      await maliciousZip.writeAsBytes(bytes);

      expect(
        () => BackupService.restoreBackup(maliciousZip.path),
        throwsA(isA<SecurityException>()),
      );
    }, skip: 'Requires path_provider platform plugin');

    test('rejects zip with backslash path traversal', () async {
      final maliciousZip = File('${tempDir.path}/malicious2.zip');
      final archive = Archive();
      archive.addFile(ArchiveFile(
        '..\\..\\..\\Windows\\System32\\config\\SAM',
        5,
        [1, 2, 3, 4, 5],
      ));
      final bytes = ZipEncoder().encode(archive);
      await maliciousZip.writeAsBytes(bytes);

      expect(
        () => BackupService.restoreBackup(maliciousZip.path),
        throwsA(isA<SecurityException>()),
      );
    }, skip: 'Requires path_provider platform plugin');

    test('accepts zip with safe paths', () async {
      final safeZip = File('${tempDir.path}/safe.zip');
      final archive = Archive();
      archive.addFile(ArchiveFile('pages/test.jpg', 5, [1, 2, 3, 4, 5]));
      archive.addFile(ArchiveFile('pdfs/doc.pdf', 5, [1, 2, 3, 4, 5]));
      final bytes = ZipEncoder().encode(archive);
      await safeZip.writeAsBytes(bytes);

      // Should not throw
      await BackupService.restoreBackup(safeZip.path);

      // Verify files were extracted
      expect(await File('${tempDir.path}/pages/test.jpg').exists(), isTrue);
      expect(await File('${tempDir.path}/pdfs/doc.pdf').exists(), isTrue);
    }, skip: 'Requires path_provider platform plugin');
  });
}
