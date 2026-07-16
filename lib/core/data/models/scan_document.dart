import 'package:isar/isar.dart';

part 'scan_document.g.dart';

@collection
class ScanDocument {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  late String filePath;
  List<String>? additionalFilePaths;

  @Index(type: IndexType.value)
  String? ocrText;

  @Index()
  late DateTime dateCreated;

  @Index(type: IndexType.value)
  late String category;

  List<String> tags = [];

  @Index(type: IndexType.value)
  String? folder;

  String? notes;

  @Index(type: IndexType.value)
  String? docType;

  @Index(type: IndexType.value)
  String fileType = 'scan';

  @Index()
  bool isFavorite = false;

  @Index()
  bool isTrashed = false;

  @Index()
  bool isArchived = false;

  @Index()
  bool isHidden = false;

  DateTime? trashedAt;

  String? barcodeFormat;
}
