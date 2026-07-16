import 'package:flutter_tts/flutter_tts.dart';

/// Simple text-to-speech wrapper for reading extracted text aloud.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> speak(String text, {String? language, double rate = 0.5}) async {
    if (text.trim().isEmpty) return;
    if (language != null) {
      await _tts.setLanguage(language);
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(1.0);
    _speaking = true;
    _tts.setCompletionHandler(() => _speaking = false);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<List<String>> languages() async {
    try {
      final langs = await _tts.getLanguages;
      return (langs as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const ['en-US'];
    }
  }

  void dispose() {
    _tts.stop();
  }
}
