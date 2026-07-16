import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device translation via ML Kit. Models download on first use per language.
class TranslationService {
  /// A curated subset of commonly used languages.
  static const Map<String, TranslateLanguage> languages = {
    'English': TranslateLanguage.english,
    'Spanish': TranslateLanguage.spanish,
    'French': TranslateLanguage.french,
    'German': TranslateLanguage.german,
    'Italian': TranslateLanguage.italian,
    'Portuguese': TranslateLanguage.portuguese,
    'Dutch': TranslateLanguage.dutch,
    'Russian': TranslateLanguage.russian,
    'Arabic': TranslateLanguage.arabic,
    'Hindi': TranslateLanguage.hindi,
    'Chinese': TranslateLanguage.chinese,
    'Japanese': TranslateLanguage.japanese,
    'Korean': TranslateLanguage.korean,
    'Turkish': TranslateLanguage.turkish,
  };

  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    final modelManager = OnDeviceTranslatorModelManager();
    for (final lang in [from, to]) {
      final code = lang.bcpCode;
      final downloaded = await modelManager.isModelDownloaded(code);
      if (!downloaded) {
        await modelManager.downloadModel(code);
      }
    }
    final translator =
        OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try {
      // Translate line by line to keep structure and avoid length limits.
      final lines = text.split('\n');
      final out = <String>[];
      for (final line in lines) {
        if (line.trim().isEmpty) {
          out.add('');
        } else {
          out.add(await translator.translateText(line));
        }
      }
      return out.join('\n');
    } finally {
      await translator.close();
    }
  }
}
