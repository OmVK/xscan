import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xscan/core/services/ai_service.dart';
import 'package:xscan/core/services/export_service.dart';
import 'package:xscan/core/services/translation_service.dart';
import 'package:xscan/core/services/tts_service.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

/// A shared text workspace: read aloud, translate, summarize, and export.
class TextToolsScreen extends StatefulWidget {
  final String initialText;
  final String title;

  const TextToolsScreen({
    super.key,
    required this.initialText,
    this.title = 'Text Tools',
  });

  @override
  State<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends State<TextToolsScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  final _tts = TtsService();
  final _translator = TranslationService();
  bool _busy = false;
  bool _speaking = false;
  String _from = 'English';
  String _to = 'Spanish';

  @override
  void dispose() {
    _controller.dispose();
    _tts.dispose();
    super.dispose();
  }

  String get _text => _controller.text;

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await _tts.speak(_text);
    }
  }

  Future<void> _translate() async {
    if (_text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await _translator.translate(
        _text,
        from: TranslationService.languages[_from]!,
        to: TranslationService.languages[_to]!,
      );
      if (!mounted) return;
      setState(() {
        _controller.text = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Translation failed: $e')));
    }
  }

  void _summarize() {
    final summary = AiService.summarize(_text, maxSentences: 4);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Summary'),
        content: SingleChildScrollView(child: Text(summary)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String format) async {
    if (_text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final name = 'text_${DateTime.now().millisecondsSinceEpoch}';
      final path = format == 'docx'
          ? await ExportService.exportDocx(name, _text)
          : await ExportService.exportTxt(name, _text);
      await ToolIO.share(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langs = TranslationService.languages.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            },
          ),
          IconButton(
            icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
            tooltip: 'Read aloud',
            onPressed: _toggleSpeak,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Text…',
                ),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _langDropdown(langs, _from, (v) => setState(() => _from = v))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(child: _langDropdown(langs, _to, (v) => setState(() => _to = v))),
                IconButton(
                  icon: const Icon(Icons.translate),
                  tooltip: 'Translate',
                  onPressed: _busy ? null : _translate,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _summarize,
                    icon: const Icon(Icons.summarize),
                    label: const Text('Summarize'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _export('txt'),
                    icon: const Icon(Icons.text_snippet),
                    label: const Text('TXT'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _export('docx'),
                    icon: const Icon(Icons.description),
                    label: const Text('DOCX'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown(
      List<String> langs, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: langs
          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
