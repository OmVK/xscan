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

final filteredDocumentsProvider =
    Provider<AsyncValue<List<ScanDocument>>>((ref) {
  final docsAsync = ref.watch(documentsStreamProvider);
  final category = ref.watch(categoryFilterProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final view = ref.watch(documentViewProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final fileType = ref.watch(fileTypeFilterProvider);

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

      final matchesSearch = searchQuery.isEmpty ||
          doc.title.toLowerCase().contains(searchQuery) ||
          (doc.ocrText != null &&
              doc.ocrText!.toLowerCase().contains(searchQuery)) ||
          (doc.notes != null &&
              doc.notes!.toLowerCase().contains(searchQuery)) ||
          (doc.folder != null &&
              doc.folder!.toLowerCase().contains(searchQuery)) ||
          (doc.barcodeFormat != null &&
              doc.barcodeFormat!.toLowerCase().contains(searchQuery)) ||
          doc.tags.any((t) => t.toLowerCase().contains(searchQuery));

      return matchesCategory &&
          matchesType &&
          matchesDate &&
          matchesSearch;
    }).toList();
  });
});
