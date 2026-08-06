import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xscan/core/data/database/isar_service.dart';
import 'package:xscan/core/data/models/scan_document.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final documentsStreamProvider = StreamProvider<List<ScanDocument>>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.listenToDocuments();
});

final categoryFilterProvider = StateProvider<String>((ref) => 'All');
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Which "shelf" of documents is currently shown.
enum DocumentView { library, favorites, archive, trash, hidden }

final documentViewProvider =
    StateProvider<DocumentView>((ref) => DocumentView.library);

/// Whether hidden documents have been unlocked this session.
final hiddenUnlockedProvider = StateProvider<bool>((ref) => false);

/// Optional date range filter.
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Optional file-type filter (e.g. 'pdf', 'scan', 'barcode', 'qr').
final fileTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Optional folder filter.
final folderFilterProvider = StateProvider<String?>((ref) => null);

/// Optional tag filter.
final tagFilterProvider = StateProvider<String?>((ref) => null);

/// Pre-computed, lower-cased search fields for each document, built only when
/// the underlying documents change. Avoids lowercasing every document's OCR
/// text on every keystroke/filter change (which was stalling the grid).
class _SearchFields {
  const _SearchFields({
    required this.title,
    required this.ocrText,
    required this.notes,
    required this.folder,
    required this.barcodeFormat,
    required this.tags,
  });

  final String title;
  final String? ocrText;
  final String? notes;
  final String? folder;
  final String? barcodeFormat;
  final List<String> tags;

  static _SearchFields from(ScanDocument doc) => _SearchFields(
        title: doc.title.toLowerCase(),
        ocrText: doc.ocrText?.toLowerCase(),
        notes: doc.notes?.toLowerCase(),
        folder: doc.folder?.toLowerCase(),
        barcodeFormat: doc.barcodeFormat?.toLowerCase(),
        tags: doc.tags.map((t) => t.toLowerCase()).toList(),
      );

  bool matches(String query) =>
      query.isEmpty ||
      title.contains(query) ||
      (ocrText?.contains(query) ?? false) ||
      (notes?.contains(query) ?? false) ||
      (folder?.contains(query) ?? false) ||
      (barcodeFormat?.contains(query) ?? false) ||
      tags.any((t) => t.contains(query));
}

final documentsSearchIndexProvider =
    Provider<Map<int, _SearchFields>>((ref) {
  final docs = ref.watch(documentsStreamProvider).value ?? const [];
  return {for (final doc in docs) doc.id: _SearchFields.from(doc)};
});

final filteredDocumentsProvider =
    Provider<AsyncValue<List<ScanDocument>>>((ref) {
  final docsAsync = ref.watch(documentsStreamProvider);
  final searchIndex = ref.watch(documentsSearchIndexProvider);
  final category = ref.watch(categoryFilterProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final view = ref.watch(documentViewProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final fileType = ref.watch(fileTypeFilterProvider);
  final folderFilter = ref.watch(folderFilterProvider);
  final tagFilter = ref.watch(tagFilterProvider);

  return docsAsync.whenData((docs) {
    return docs.where((doc) {
      // View shelf gating.
      switch (view) {
        case DocumentView.trash:
          if (!doc.isTrashed) return false;
          break;
        case DocumentView.favorites:
          if (doc.isTrashed || !doc.isFavorite) return false;
          if (doc.isHidden) return false;
          break;
        case DocumentView.archive:
          if (doc.isTrashed || !doc.isArchived) return false;
          if (doc.isHidden) return false;
          break;
        case DocumentView.hidden:
          if (doc.isTrashed || !doc.isHidden) return false;
          break;
        case DocumentView.library:
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

      final matchesSearch =
          searchIndex[doc.id]?.matches(query) ?? query.isEmpty;

      return matchesCategory &&
          matchesType &&
          matchesDate &&
          matchesSearch &&
          (folderFilter == null || folderFilter.isEmpty ||
              (doc.folder != null && doc.folder == folderFilter)) &&
          (tagFilter == null || tagFilter.isEmpty || doc.tags.contains(tagFilter));
    }).toList();
  });
});
