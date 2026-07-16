import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// A file that arrived from another app (share / open-with).
class IncomingFile {
  IncomingFile(this.path, this.isPdf);
  final String path;
  final bool isPdf;
}

/// Normalizes incoming shared media into PDF / image buckets.
class IncomingShareService {
  static bool _looksPdf(String path) => path.toLowerCase().endsWith('.pdf');

  static List<IncomingFile> _map(List<SharedMediaFile> files) {
    return files
        .where((f) =>
            f.type == SharedMediaType.file || f.type == SharedMediaType.image)
        .map((f) => IncomingFile(f.path, _looksPdf(f.path)))
        .toList();
  }

  /// Files the app was launched with (cold start via share / open-with).
  static Future<List<IncomingFile>> initial() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    return _map(media);
  }

  /// Files shared while the app is already running.
  static Stream<List<IncomingFile>> stream() {
    return ReceiveSharingIntent.instance.getMediaStream().map(_map);
  }

  static void reset() => ReceiveSharingIntent.instance.reset();
}
