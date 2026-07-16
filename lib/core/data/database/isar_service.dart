import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xscan/core/data/models/scan_document.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [ScanDocumentSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<void> saveDocument(ScanDocument doc) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.scanDocuments.put(doc);
    });
  }

  Future<List<ScanDocument>> getAllDocuments() async {
    final isar = await db;
    return await isar.scanDocuments.where().sortByDateCreatedDesc().findAll();
  }

  /// Moves a document to the trash (soft delete).
  Future<void> trashDocument(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final doc = await isar.scanDocuments.get(id);
      if (doc != null) {
        doc.isTrashed = true;
        doc.trashedAt = DateTime.now();
        await isar.scanDocuments.put(doc);
      }
    });
  }

  Future<void> restoreDocument(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final doc = await isar.scanDocuments.get(id);
      if (doc != null) {
        doc.isTrashed = false;
        doc.trashedAt = null;
        await isar.scanDocuments.put(doc);
      }
    });
  }

  /// Permanently deletes the DB record and securely wipes its files.
  Future<void> deleteDocument(Id id, {bool secure = true}) async {
    final isar = await db;
    final doc = await isar.scanDocuments.get(id);
    if (doc != null) {
      final paths = <String>[
        if (doc.filePath.isNotEmpty) doc.filePath,
        ...?doc.additionalFilePaths,
      ];
      for (final path in paths) {
        await _deleteFile(path, secure: secure);
      }
    }
    await isar.writeTxn(() async {
      await isar.scanDocuments.delete(id);
    });
  }

  Future<void> _deleteFile(String path, {required bool secure}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      if (secure) {
        final length = await file.length();
        final sink = file.openWrite(mode: FileMode.write);
        const chunk = 4096;
        var written = 0;
        final zeros = List<int>.filled(chunk, 0);
        while (written < length) {
          final remaining = length - written;
          sink.add(remaining >= chunk ? zeros : List<int>.filled(remaining, 0));
          written += chunk;
        }
        await sink.flush();
        await sink.close();
      }
      await file.delete();
    } catch (_) {
      // Best-effort deletion.
    }
  }

  Future<void> emptyTrash({bool secure = true}) async {
    final isar = await db;
    final trashed =
        await isar.scanDocuments.filter().isTrashedEqualTo(true).findAll();
    for (final doc in trashed) {
      await deleteDocument(doc.id, secure: secure);
    }
  }

  Stream<List<ScanDocument>> listenToDocuments() async* {
    final isar = await db;
    yield* isar.scanDocuments
        .where()
        .sortByDateCreatedDesc()
        .watch(fireImmediately: true);
  }
}
