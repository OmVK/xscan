import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';

void main() {
  group('PdfToolsService.parseRanges', () {
    test('parses single pages', () {
      final result = PdfToolsService.parseRanges('1, 3, 5', 10);
      expect(result, [
        [0],
        [2],
        [4],
      ]);
    });

    test('parses inclusive ranges into 0-based indices', () {
      final result = PdfToolsService.parseRanges('1-3', 10);
      expect(result, [
        [0, 1, 2],
      ]);
    });

    test('mixes ranges and singletons, one group per token', () {
      final result = PdfToolsService.parseRanges('1-2, 4, 6-7', 10);
      expect(result, [
        [0, 1],
        [3],
        [5, 6],
      ]);
    });

    test('clamps out-of-bounds pages', () {
      final result = PdfToolsService.parseRanges('3-99', 5);
      expect(result, [
        [2, 3, 4],
      ]);
    });

    test('handles reversed ranges', () {
      final result = PdfToolsService.parseRanges('5-3', 10);
      expect(result, [
        [2, 3, 4],
      ]);
    });

    test('ignores invalid / empty tokens', () {
      final result = PdfToolsService.parseRanges('abc, , 2, 100', 3);
      expect(result, [
        [1],
      ]);
    });

    test('returns empty for blank spec', () {
      expect(PdfToolsService.parseRanges('   ', 10), isEmpty);
    });
  });
}
