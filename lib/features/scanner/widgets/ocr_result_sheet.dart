import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

/// Shows an executive interactive OCR result bottom sheet with Text-to-Speech,
/// structured entity chips, on-device translation, and export options.
void showOcrResultSheet(BuildContext context, OcrResult result) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OcrResultSheetWidget(result: result),
  );
}

class _OcrResultSheetWidget extends StatefulWidget {
  final OcrResult result;

  const _OcrResultSheetWidget({required this.result});

  @override
  State<_OcrResultSheetWidget> createState() => _OcrResultSheetWidgetState();
}

class _OcrResultSheetWidgetState extends State<_OcrResultSheetWidget> {
  late FlutterTts _tts;
  bool _isPlaying = false;
  String _activeText = '';
  String _translatedText = '';
  bool _isTranslating = false;
  TranslateLanguage _targetLang = TranslateLanguage.spanish;

  final Map<String, TranslateLanguage> _languages = {
    'Spanish': TranslateLanguage.spanish,
    'Arabic': TranslateLanguage.arabic,
    'French': TranslateLanguage.french,
    'German': TranslateLanguage.german,
    'Chinese': TranslateLanguage.chinese,
    'Hindi': TranslateLanguage.hindi,
    'Japanese': TranslateLanguage.japanese,
  };

  @override
  void initState() {
    super.initState();
    _activeText = widget.result.text;
    _initTts();
  }

  void _initTts() {
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
    } else {
      if (_activeText.isEmpty) return;
      setState(() => _isPlaying = true);
      await _tts.speak(_activeText);
    }
  }

  Future<void> _translateText(TranslateLanguage target) async {
    if (_activeText.isEmpty) return;
    setState(() {
      _isTranslating = true;
      _targetLang = target;
    });

    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final isDownloaded = await modelManager.isModelDownloaded(target.bcpCode);
      if (!isDownloaded) {
        await modelManager.downloadModel(target.bcpCode);
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: target,
      );

      final translated = await translator.translateText(_activeText);
      await translator.close();

      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entities = widget.result.entities;
    final displayText = _translatedText.isNotEmpty ? _translatedText : _activeText;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.text_snippet, color: Color(0xFF00E5FF)),
                const SizedBox(width: 10),
                const Text(
                  'Extracted Text (OCR)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.volume_up),
                  color: const Color(0xFF00E5FF),
                  iconSize: 28,
                  onPressed: _toggleSpeech,
                  tooltip: _isPlaying ? 'Pause Speech' : 'Listen Text-To-Speech',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Entity Extraction Chips (Emails, Phones, URLs, Amounts)
                if (!entities.isEmpty) ...[
                  const Text('Recognized Entities',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...entities.emails.map((e) => ActionChip(
                            avatar: const Icon(Icons.email, size: 14),
                            label: Text(e),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: e));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Email copied: $e')),
                              );
                            },
                          )),
                      ...entities.phones.map((p) => ActionChip(
                            avatar: const Icon(Icons.phone, size: 14),
                            label: Text(p),
                            onPressed: () => launchUrl(Uri.parse('tel:$p')),
                          )),
                      ...entities.urls.map((u) => ActionChip(
                            avatar: const Icon(Icons.link, size: 14),
                            label: Text(u),
                            onPressed: () => launchUrl(Uri.parse(u)),
                          )),
                      ...entities.amounts.map((a) => Chip(
                            avatar: const Icon(Icons.attach_money, size: 14, color: Colors.green),
                            label: Text(a, style: const TextStyle(fontWeight: FontWeight.bold)),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // On-Device Translation Bar
                Row(
                  children: [
                    const Icon(Icons.g_translate, size: 18),
                    const SizedBox(width: 8),
                    const Text('Translate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _languages.entries.map((entry) {
                            final selected = _targetLang == entry.value && _translatedText.isNotEmpty;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                                selected: selected,
                                onSelected: (_) => _translateText(entry.value),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isTranslating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),

                // Extracted Text View Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2030) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: SelectableText(
                    displayText,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Quick Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2030) : Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: displayText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final path = await AppStorage.writeExport(
                        'ocr_text.txt',
                        displayText.codeUnits,
                      );
                      ToolIO.share(path);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share TXT'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
