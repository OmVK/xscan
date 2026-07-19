import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/data/models/scan_document.dart';

/// Tests the filtering logic that would be in filteredDocumentsProvider.
/// We extract and test the pure filtering function directly.
List<ScanDocument> filterDocuments({
  required List<ScanDocument> docs,
  required String view,
  required String category,
  required String searchQuery,
  DateTimeRange? dateRange,
  String? fileType,
}) {
  return docs.where((doc) {
    switch (view) {
      case 'trash':
        if (!doc.isTrashed) return false;
        break;
      case 'favorites':
        if (doc.isTrashed || !doc.isFavorite) return false;
        if (doc.isHidden) return false;
        break;
      case 'archive':
        if (doc.isTrashed || !doc.isArchived) return false;
        if (doc.isHidden) return false;
        break;
      case 'hidden':
        if (doc.isTrashed || !doc.isHidden) return false;
        break;
      case 'library':
      default:
        if (doc.isTrashed || doc.isHidden || doc.isArchived) return false;
        break;
    }

    final matchesCategory = category == 'All' || doc.category == category;
    final matchesType = fileType == null || doc.fileType == fileType;

    final matchesDate = dateRange == null ||
        (doc.dateCreated.isAfter(
              dateRange.start.subtract(const Duration(days: 1)),
            ) &&
            doc.dateCreated
                .isBefore(dateRange.end.add(const Duration(days: 1))));

    final q = searchQuery.toLowerCase();
    final matchesSearch = q.isEmpty ||
        doc.title.toLowerCase().contains(q) ||
        (doc.ocrText != null && doc.ocrText!.toLowerCase().contains(q)) ||
        (doc.notes != null && doc.notes!.toLowerCase().contains(q)) ||
        (doc.folder != null && doc.folder!.toLowerCase().contains(q)) ||
        (doc.barcodeFormat != null &&
            doc.barcodeFormat!.toLowerCase().contains(q)) ||
        doc.tags.any((t) => t.toLowerCase().contains(q));

    return matchesCategory && matchesType && matchesDate && matchesSearch;
  }).toList();
}

ScanDocument _doc({
  String title = 'Test',
  String category = 'Documents',
  String fileType = 'scan',
  bool isTrashed = false,
  bool isFavorite = false,
  bool isArchived = false,
  bool isHidden = false,
  String? ocrText,
  String? notes,
  String? folder,
  String? barcodeFormat,
  List<String> tags = const [],
  DateTime? dateCreated,
}) {
  final doc = ScanDocument()
    ..title = title
    ..category = category
    ..fileType = fileType
    ..isTrashed = isTrashed
    ..isFavorite = isFavorite
    ..isArchived = isArchived
    ..isHidden = isHidden
    ..dateCreated = dateCreated ?? DateTime(2026, 1, 15);
  doc.ocrText = ocrText;
  doc.notes = notes;
  doc.folder = folder;
  doc.barcodeFormat = barcodeFormat;
  doc.tags = tags;
  return doc;
}

void main() {
  group('Library view', () {
    test('excludes trashed documents', () {
      final docs = [_doc(), _doc(isTrashed: true)];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: '');
      expect(result.length, 1);
    });

    test('excludes hidden documents', () {
      final docs = [_doc(), _doc(isHidden: true)];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: '');
      expect(result.length, 1);
    });

    test('excludes archived documents', () {
      final docs = [_doc(), _doc(isArchived: true)];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: '');
      expect(result.length, 1);
    });
  });

  group('Favorites view', () {
    test('shows only favorites', () {
      final docs = [_doc(), _doc(isFavorite: true)];
      final result = filterDocuments(docs: docs, view: 'favorites', category: 'All', searchQuery: '');
      expect(result.length, 1);
      expect(result.first.isFavorite, isTrue);
    });

    test('excludes trashed favorites', () {
      final docs = [_doc(isFavorite: true, isTrashed: true)];
      final result = filterDocuments(docs: docs, view: 'favorites', category: 'All', searchQuery: '');
      expect(result, isEmpty);
    });
  });

  group('Trash view', () {
    test('shows only trashed', () {
      final docs = [_doc(), _doc(isTrashed: true)];
      final result = filterDocuments(docs: docs, view: 'trash', category: 'All', searchQuery: '');
      expect(result.length, 1);
      expect(result.first.isTrashed, isTrue);
    });
  });

  group('Hidden view', () {
    test('shows only hidden', () {
      final docs = [_doc(), _doc(isHidden: true)];
      final result = filterDocuments(docs: docs, view: 'hidden', category: 'All', searchQuery: '');
      expect(result.length, 1);
      expect(result.first.isHidden, isTrue);
    });
  });

  group('Category filter', () {
    test('filters by category', () {
      final docs = [
        _doc(category: 'Receipts'),
        _doc(category: 'Documents'),
        _doc(category: 'Receipts'),
      ];
      final result = filterDocuments(docs: docs, view: 'library', category: 'Receipts', searchQuery: '');
      expect(result.length, 2);
    });

    test('All category shows everything', () {
      final docs = [_doc(category: 'A'), _doc(category: 'B')];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: '');
      expect(result.length, 2);
    });
  });

  group('Search query', () {
    test('searches by title', () {
      final docs = [_doc(title: 'Invoice ABC'), _doc(title: 'Receipt XYZ')];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: 'Invoice');
      expect(result.length, 1);
      expect(result.first.title, 'Invoice ABC');
    });

    test('searches by OCR text', () {
      final docs = [
        _doc(title: 'A')..ocrText = 'Hello World',
        _doc(title: 'B')..ocrText = 'Goodbye World',
      ];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: 'Hello');
      expect(result.length, 1);
    });

    test('searches by tags', () {
      final docs = [
        _doc(title: 'A', tags: ['tax', '2026']),
        _doc(title: 'B', tags: ['personal']),
      ];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: 'tax');
      expect(result.length, 1);
    });

    test('search is case-insensitive', () {
      final docs = [_doc(title: 'Invoice')];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: 'invoice');
      expect(result.length, 1);
    });
  });

  group('File type filter', () {
    test('filters by file type', () {
      final docs = [_doc(fileType: 'scan'), _doc(fileType: 'barcode')];
      final result = filterDocuments(docs: docs, view: 'library', category: 'All', searchQuery: '', fileType: 'barcode');
      expect(result.length, 1);
      expect(result.first.fileType, 'barcode');
    });
  });

  group('Date range filter', () {
    test('filters by date range', () {
      final docs = [
        _doc(dateCreated: DateTime(2026, 1, 1)),
        _doc(dateCreated: DateTime(2026, 6, 15)),
        _doc(dateCreated: DateTime(2026, 12, 31)),
      ];
      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 9, 30),
      );
      final result = filterDocuments(
        docs: docs,
        view: 'library',
        category: 'All',
        searchQuery: '',
        dateRange: range,
      );
      expect(result.length, 1);
    });
  });
}
