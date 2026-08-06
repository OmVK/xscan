import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xscan/core/services/path_safety.dart';

void main() {
  final base = p.join('app', 'documents');

  group('zipEntryIsSafe', () {
    test('accepts a file inside the base', () {
      expect(zipEntryIsSafe(base, 'pages/scan_1.png'), isTrue);
    });

    test('accepts nested directories', () {
      expect(zipEntryIsSafe(base, 'pdfs/a/b/c/out.pdf'), isTrue);
    });

    test('accepts an entry equal to the base itself', () {
      expect(zipEntryIsSafe(base, '.'), isTrue);
      expect(zipEntryIsSafe(base, ''), isTrue);
    });

    test('rejects dot-dot path traversal (zip-slip)', () {
      expect(zipEntryIsSafe(base, '../secret.txt'), isFalse);
      expect(zipEntryIsSafe(base, '../../etc/passwd'), isFalse);
      expect(zipEntryIsSafe(base, 'pages/../../../etc/shadow'), isFalse);
    });

    test('rejects an escaped absolute path', () {
      final absoluteEscape = Platform.isWindows
          ? r'C:\evil\rootkit.exe'
          : '/evil/bin/rootkit';
      expect(zipEntryIsSafe(base, absoluteEscape), isFalse);
    });

    test('rejects a sibling that merely shares the base name prefix', () {
      expect(
        zipEntryIsSafe(p.join('app', 'documents2'), 'inside'),
        isFalse,
      );
    });

    test('rejects mixed-separator traversal', () {
      // Backslashes are only separators on Windows; on POSIX that string is a
      // literal innocent filename, so only assert the Windows behaviour.
      final result = zipEntryIsSafe(base, 'pages/..\\..\\escape.png');
      expect(result, isNot(Platform.isWindows));
    });

    test('canonicalises dots and double separators before checking', () {
      expect(zipEntryIsSafe(base, 'pages//sub/../page.png'), isTrue);
    });
  });
}