import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:xscan/core/services/app_storage.dart';

/// Small IO helpers shared across the PDF tool screens.
class ToolIO {
  /// Lets the user pick one or many images. Returns absolute paths.
  static Future<List<String>> pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    return files.map((f) => f.path).toList();
  }

  /// Shares a produced file.
  static Future<void> share(String path, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: text),
    );
  }

  /// Shares multiple produced files at once.
  static Future<void> shareMany(List<String> paths, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: paths.map((p) => XFile(p)).toList(), text: text),
    );
  }

  /// Saves bytes to local export storage and returns the saved file path.
  static Future<String> saveToGallery(List<int> bytes, String name) async {
    return AppStorage.writeExport(name, bytes);
  }
}
