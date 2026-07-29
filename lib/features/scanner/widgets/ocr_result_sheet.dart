import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/pdf_service.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';
import 'package:xscan/features/scanner/widgets/interactive_ocr_canvas.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

enum OcrStudioMode { canvas, reflow, split }

/// Shows an executive interactive OCR result bottom sheet studio with mode selection,
/// Text-to-Speech, and PDF export.
void showOcrResultSheet(BuildContext context, OcrResult result, {String? imagePath}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OcrResultSheetWidget(
      result: result,
      imagePath: imagePath ?? result.imagePath,
    ),
  );
}

class _OcrResultSheetWidget extends StatefulWidget {
  final OcrResult result;
  final String? imagePath;

  const _OcrResultSheetWidget({
    required this.result,
    this.imagePath,
  });

  @override
  State<_OcrResultSheetWidget> createState() => _OcrResultSheetWidgetState();
}

class _OcrResultSheetWidgetState extends State<_OcrResultSheetWidget> {
  late FlutterTts _tts;
  bool _isPlaying = false;
  late String _activeText;
  final OcrStudioMode _currentMode = OcrStudioMode.canvas;

  @override
  void initState() {
    super.initState();
    _activeText = widget.result.fullEditedText;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entities = widget.result.entities;
    final displayText = _activeText;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF)),
                const SizedBox(width: 10),
                Text(
                  'Interactive OCR Studio',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.volume_up),
                  color: const Color(0xFF00E5FF),
                  iconSize: 26,
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

          const SizedBox(height: 4),
          const Divider(height: 1),

          // Body Content based on Mode
          Expanded(
            child: _buildStudioBody(context, displayText, entities),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(14),
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
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportWordDocx,
                    icon: const Icon(Icons.description_rounded, size: 18, color: Color(0xFF185ABD)),
                    label: const Text('Export Word'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final pdfService = PdfService();
                        final path = await pdfService.generateSearchablePdfFromOcr(widget.result);
                        ToolIO.share(path);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('PDF export failed: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Export PDF'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportWordDocx() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final title = widget.result.lines.isNotEmpty ? widget.result.lines.first.currentText : 'OCR Document';
      final buffer = StringBuffer();
      buffer.writeln('{\\rtf1\\ansi\\deff0');
      buffer.writeln('{\\fonttbl{\\f0 Arial;}}');
      buffer.writeln('\\f0\\fs28\\b $title\\b0\\par\\par');
      
      for (final line in widget.result.lines) {
        final clean = line.currentText
            .replaceAll('\\', '\\\\')
            .replaceAll('{', '\\{')
            .replaceAll('}', '\\}');
        buffer.writeln('$clean\\par');
      }
      buffer.writeln('}');

      final path = await AppStorage.writeExport(
        'scanned_document.docx',
        buffer.toString().codeUnits,
      );
      ToolIO.share(path);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Word export failed: $e')),
      );
    }
  }

  Widget _buildStudioBody(
    BuildContext context,
    String displayText,
    OcrEntities entities,
  ) {
    switch (_currentMode) {
      case OcrStudioMode.canvas:
        return InteractiveOcrCanvas(
          result: widget.result,
          imagePath: widget.imagePath,
          onLineUpdated: (line) {
            setState(() {
              _activeText = widget.result.fullEditedText;
            });
          },
        );

      case OcrStudioMode.reflow:
        return _buildMsWordDocumentPage(context, displayText, entities);

      case OcrStudioMode.split:
        return Column(
          children: [
            Expanded(
              flex: 5,
              child: InteractiveOcrCanvas(
                result: widget.result,
                imagePath: widget.imagePath,
                onLineUpdated: (line) {
                  setState(() {
                    _activeText = widget.result.fullEditedText;
                  });
                },
              ),
            ),
            const Divider(height: 1, thickness: 2, color: Colors.blueAccent),
            Expanded(
              flex: 5,
              child: _buildMsWordDocumentPage(context, displayText, entities),
            ),
          ],
        );
    }
  }

  /// Builds an MS Word-style paper document page with margins, formatting header,
  /// word count, and structured inline paragraph editing.
  Widget _buildMsWordDocumentPage(
    BuildContext context,
    String displayText,
    OcrEntities entities,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final wordCount = displayText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;

    final paperBg = isDark ? const Color(0xFF1E2433) : Colors.white;
    final paperTextColor = isDark ? Colors.grey.shade100 : const Color(0xFF1A1A1A);

    return Container(
      color: isDark ? const Color(0xFF0F121C) : const Color(0xFFEFEFEF),
      child: Column(
        children: [
          // MS Word Toolbar / Document Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B26) : Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185ABD), // MS Word Blue
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.description_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'MS Word Page View',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$wordCount words • Page 1',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                    ),
                  ),
                ),
                const Spacer(),
                if (!entities.isEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.hub_rounded, size: 20),
                    tooltip: 'Entities Found',
                    itemBuilder: (context) => [
                      ...entities.emails.map((e) => PopupMenuItem(value: e, child: Text('Email: $e'))),
                      ...entities.phones.map((p) => PopupMenuItem(value: p, child: Text('Phone: $p'))),
                      ...entities.urls.map((u) => PopupMenuItem(value: u, child: Text('Link: $u'))),
                    ],
                  ),
              ],
            ),
          ),

          // Scrollable Word Paper Document Page Sheet
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  decoration: BoxDecoration(
                    color: paperBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Document Header Stamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DOCUMENT REFLOW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            DateTime.now().toLocal().toString().split(' ')[0],
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      const SizedBox(height: 8),

                      // Document Lines / Paragraphs (Editable Word Layout)
                      if (widget.result.lines.isEmpty)
                        SelectableText(
                          displayText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: paperTextColor,
                            fontFamily: 'Roboto',
                          ),
                        )
                      else
                        ...widget.result.lines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          final isTitle = index == 0 && line.currentText.length < 40;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextFormField(
                              initialValue: line.currentText,
                              maxLines: null,
                              style: TextStyle(
                                fontSize: isTitle ? 18 : 14,
                                fontWeight: isTitle || line.isEdited ? FontWeight.bold : FontWeight.normal,
                                height: 1.5,
                                color: line.isEdited ? Colors.blue.shade700 : paperTextColor,
                                fontFamily: 'Roboto',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: InputBorder.none,
                                hoverColor: Colors.blue.withValues(alpha: 0.05),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  line.currentText = val;
                                  _activeText = widget.result.fullEditedText;
                                });
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
