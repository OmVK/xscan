import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xscan/features/scanner/services/ocr_service.dart';

/// An interactive page canvas widget that overlays recognized OCR text lines
/// directly over the document page image, allowing tap-to-edit, white-out replacement,
/// text selection, and gesture zoom.
class InteractiveOcrCanvas extends StatefulWidget {
  final OcrResult result;
  final String? imagePath;
  final Function(OcrLine line)? onLineUpdated;
  final bool isEditable;

  const InteractiveOcrCanvas({
    super.key,
    required this.result,
    this.imagePath,
    this.onLineUpdated,
    this.isEditable = true,
  });

  @override
  State<InteractiveOcrCanvas> createState() => _InteractiveOcrCanvasState();
}

class _InteractiveOcrCanvasState extends State<InteractiveOcrCanvas> {
  OcrLine? _selectedLine;
  bool _showAllOutlines = false; // Default to clean uncluttered view
  double _baseFontSizeOnScaleStart = 14.0;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _openLineEditor(OcrLine line) {
    if (!widget.isEditable) return;
    setState(() => _selectedLine = line);

    final controller = TextEditingController(text: line.currentText);
    Color textColor = line.textColor;
    Color bgColor = line.backgroundColor;
    bool whiteout = line.isWhiteout;
    double currentFontSize = line.fontSize ?? 14.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Page Text',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Smart Symbol Formatting Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.check_box_outlined, size: 16),
                            label: const Text('Checkbox'),
                            onPressed: () {
                              setModalState(() {
                                if (!controller.text.startsWith('[ ]') && !controller.text.startsWith('[x]')) {
                                  controller.text = '[ ] ${controller.text}';
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                            label: const Text('Bullet List'),
                            onPressed: () {
                              setModalState(() {
                                if (!controller.text.startsWith('•')) {
                                  controller.text = '• ${controller.text}';
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.title_rounded, size: 16),
                            label: const Text('Plain Text'),
                            onPressed: () {
                              setModalState(() {
                                controller.text = controller.text.replaceAll(RegExp(r'^(\[[\sxXvV]\]|[\u2022\u25CF\*])\s*'), '');
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      minLines: 2,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      decoration: InputDecoration(
                        labelText: 'Text on Page',
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: controller.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Switch(
                          value: whiteout,
                          onChanged: (val) {
                            setModalState(() => whiteout = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'White-out Background Mask',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Hide original scanned text beneath',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (whiteout) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Paper Tone Match',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const {
                              'White': Color(0xFFFFFFFF),
                              'Cream': Color(0xFFFDFBF7),
                              'Parchment': Color(0xFFF5EBE0),
                              'Light Grey': Color(0xFFF0F0F0),
                              'Dark Slate': Color(0xFF1F2937),
                            }.entries.map((e) {
                              final isSelected = bgColor.toARGB32() == e.value.toARGB32();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  avatar: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: e.value,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey),
                                    ),
                                  ),
                                  label: Text(e.key, style: const TextStyle(fontSize: 11)),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setModalState(() {
                                      bgColor = e.value;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ].expand((x) => x).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.format_size_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Size: ${currentFontSize.round()} pt',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.text_decrease_rounded, size: 20),
                          tooltip: 'Decrease Font Size',
                          onPressed: () {
                            setModalState(() {
                              currentFontSize = (currentFontSize - 2.0).clamp(8.0, 48.0);
                            });
                          },
                        ),
                        SizedBox(
                          width: 140,
                          child: Slider(
                            value: currentFontSize.clamp(8.0, 48.0),
                            min: 8.0,
                            max: 48.0,
                            divisions: 40,
                            onChanged: (val) {
                              setModalState(() {
                                currentFontSize = val;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.text_increase_rounded, size: 20),
                          tooltip: 'Increase Font Size',
                          onPressed: () {
                            setModalState(() {
                              currentFontSize = (currentFontSize + 2.0).clamp(8.0, 48.0);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (line.customLeft != null || line.customTop != null || line.fontSize != null) ...[
                          TextButton.icon(
                            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                            label: const Text('Reset Format'),
                            onPressed: () {
                              setModalState(() {
                                line.resetPosition();
                                line.fontSize = null;
                                currentFontSize = 14.0;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: const Text('Reset Text'),
                          onPressed: () {
                            setModalState(() {
                              controller.text = line.text;
                              whiteout = true;
                              line.resetPosition();
                              line.fontSize = null;
                              currentFontSize = 14.0;
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Apply Changes'),
                          onPressed: () {
                            setState(() {
                              line.currentText = controller.text;
                              line.isWhiteout = whiteout;
                              line.textColor = textColor;
                              line.backgroundColor = bgColor;
                              line.fontSize = currentFontSize;
                            });
                            widget.onLineUpdated?.call(line);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = widget.imagePath ?? widget.result.imagePath;

    if (imagePath == null || !File(imagePath).existsSync()) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Source image file not available for page canvas.'),
          ],
        ),
      );
    }

    final int nativeW = widget.result.imageWidth > 0
        ? widget.result.imageWidth
        : 1000;
    final int nativeH = widget.result.imageHeight > 0
        ? widget.result.imageHeight
        : 1400;
    final double aspectRatio = nativeW / nativeH;

    return Column(
      children: [
        // Canvas Toolbar with Quick Resize Controls when a text box is selected
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_selectedLine == null) ...[
                  Icon(Icons.open_with_rounded,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Tap text line to edit or drag to move',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ] else ...[
                  // 1-Tap Quick Resize & Format Controls for Selected Box
                  ActionChip(
                    avatar: const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.blue),
                    label: const Text('Enlarge +', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        final line = _selectedLine!;
                        line.customWidth = ((line.customWidth ?? line.box.width) + 35.0).clamp(30.0, nativeW.toDouble());
                        line.customHeight = ((line.customHeight ?? line.box.height) + 12.0).clamp(14.0, nativeH.toDouble());
                        line.fontSize = ((line.fontSize ?? 14.0) + 2.0).clamp(8.0, 60.0);
                      });
                      widget.onLineUpdated?.call(_selectedLine!);
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.zoom_out_rounded, size: 16, color: Colors.deepOrange),
                    label: const Text('Shrink -', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        final line = _selectedLine!;
                        line.customWidth = ((line.customWidth ?? line.box.width) - 25.0).clamp(30.0, nativeW.toDouble());
                        line.customHeight = ((line.customHeight ?? line.box.height) - 8.0).clamp(14.0, nativeH.toDouble());
                        line.fontSize = ((line.fontSize ?? 14.0) - 2.0).clamp(8.0, 60.0);
                      });
                      widget.onLineUpdated?.call(_selectedLine!);
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Wider ↔', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        final line = _selectedLine!;
                        line.customWidth = ((line.customWidth ?? line.box.width) + 45.0).clamp(30.0, nativeW.toDouble());
                      });
                      widget.onLineUpdated?.call(_selectedLine!);
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Text', style: TextStyle(fontSize: 11)),
                    onPressed: () => _openLineEditor(_selectedLine!),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  tooltip: 'Add Text Box',
                  onPressed: () {
                    final newLine = OcrLine.newText(
                      'New Text Box',
                      x: nativeW * 0.2,
                      y: nativeH * 0.3,
                    );
                    setState(() {
                      widget.result.lines.add(newLine);
                      _selectedLine = newLine;
                    });
                    widget.onLineUpdated?.call(newLine);
                    _openLineEditor(newLine);
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Show Boxes', style: TextStyle(fontSize: 11)),
                  selected: _showAllOutlines,
                  onSelected: (val) {
                    setState(() => _showAllOutlines = val);
                  },
                  avatar: Icon(
                    _showAllOutlines
                        ? Icons.crop_free_rounded
                        : Icons.border_clear_rounded,
                    size: 14,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                  tooltip: 'Reset Zoom',
                  onPressed: () {
                    _transformationController.value = Matrix4.identity();
                  },
                ),
              ],
            ),
          ),
        ),

        // Canvas Area with Pinch-to-Zoom
        Expanded(
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              color: Colors.grey.shade900,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canvasW = constraints.maxWidth;
                        final canvasH = constraints.maxHeight;

                        final scaleX = canvasW / nativeW;
                        final scaleY = canvasH / nativeH;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Base Document Image
                            Image.file(
                              File(imagePath),
                              fit: BoxFit.fill,
                              width: canvasW,
                              height: canvasH,
                            ),

                            // Erase Masks over Original Text Locations when lines are moved or edited
                            ...widget.result.lines
                                .where((l) => (l.customLeft != null || l.customTop != null || l.isEdited) && l.isWhiteout)
                                .map((line) {
                              final origLeft = line.box.left * scaleX;
                              final origTop = line.box.top * scaleY;
                              final origWidth = (line.box.width * scaleX).clamp(16.0, canvasW);
                              final origHeight = (line.box.height * scaleY).clamp(14.0, canvasH);

                              return Positioned(
                                left: origLeft,
                                top: origTop,
                                width: origWidth,
                                height: origHeight,
                                child: Container(
                                  color: line.backgroundColor,
                                ),
                              );
                            }),

                            // Overlay Recognized & Editable Lines
                            ...widget.result.lines.map((line) {
                              final isSelected = line == _selectedLine;
                              final left = line.effectiveLeft * scaleX;
                              final top = line.effectiveTop * scaleY;
                              final rawBaseWidth = line.effectiveWidth * scaleX;
                              final rawBaseHeight = line.effectiveHeight * scaleY;

                              // Multi-line height support when user presses Enter
                              final lineCount = line.currentText.split('\n').length;
                              final calculatedBaseH = (rawBaseHeight * (lineCount < 1 ? 1 : lineCount)).clamp(14.0, canvasH);
                              final height = (canvasH - top).clamp(14.0, calculatedBaseH);

                              // Dynamic forward box expansion when typing extra words
                              final textLengthRatio = line.text.isEmpty
                                  ? 1.0
                                  : (line.currentText.length / line.text.length);
                              final maxAvailableW = (canvasW - left).clamp(rawBaseWidth, canvasW);
                              final width = (rawBaseWidth * (textLengthRatio < 1.0 ? 1.0 : textLengthRatio))
                                  .clamp(rawBaseWidth, maxAvailableW);

                              final calculatedFontSize =
                                  (height / (lineCount < 1 ? 1 : lineCount) * 0.72).clamp(8.0, 36.0);

                               return Positioned(
                                left: left,
                                top: top,
                                width: width,
                                height: height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openLineEditor(line),
                                      onScaleStart: !widget.isEditable
                                          ? null
                                          : (details) {
                                              _baseFontSizeOnScaleStart =
                                                  line.fontSize ?? calculatedFontSize;
                                            },
                                      onScaleUpdate: !widget.isEditable
                                          ? null
                                          : (details) {
                                              setState(() {
                                                _selectedLine = line;
                                                if (details.scale != 1.0) {
                                                  final newFont = (_baseFontSizeOnScaleStart * details.scale)
                                                      .clamp(8.0, 60.0);
                                                  line.fontSize = newFont;
                                                }
                                                if (details.pointerCount == 1 && details.focalPointDelta != Offset.zero) {
                                                  final dx = details.focalPointDelta.dx / scaleX;
                                                  final dy = details.focalPointDelta.dy / scaleY;
                                                  line.customLeft = (line.effectiveLeft + dx)
                                                      .clamp(0.0, nativeW.toDouble());
                                                  line.customTop = (line.effectiveTop + dy)
                                                      .clamp(0.0, nativeH.toDouble());
                                                }
                                              });
                                              widget.onLineUpdated?.call(line);
                                            },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: width,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: line.isWhiteout
                                              ? line.backgroundColor
                                              : (isSelected
                                                  ? theme.colorScheme.primary
                                                      .withValues(alpha: 0.25)
                                                  : (_showAllOutlines
                                                      ? theme.colorScheme.primary
                                                          .withValues(alpha: 0.08)
                                                      : Colors.transparent)),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : (line.isEdited
                                                    ? Colors.amber.shade700
                                                    : (_showAllOutlines
                                                        ? theme.colorScheme.primary
                                                            .withValues(alpha: 0.35)
                                                        : Colors.transparent)),
                                            width: isSelected ? 2.0 : 1.0,
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            if (isSelected)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 2),
                                                child: Icon(
                                                  Icons.drag_indicator_rounded,
                                                  size: (height * 0.5).clamp(10.0, 18.0),
                                                  color: Colors.amber.shade800,
                                                ),
                                              ),
                                            if (line.kind == OcrLineKind.checkbox)
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    line.toggleCheckbox();
                                                  });
                                                  widget.onLineUpdated?.call(line);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Icon(
                                                    line.isChecked
                                                        ? Icons.check_box_rounded
                                                        : Icons.check_box_outline_blank_rounded,
                                                    size: (height * 0.6).clamp(12.0, 24.0),
                                                    color: line.isChecked
                                                        ? Colors.blue.shade600
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  line.currentText,
                                                  style: TextStyle(
                                                    color: line.textColor,
                                                    fontSize: line.fontSize ?? calculatedFontSize,
                                                    fontWeight: line.isEdited
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Resize Corner Handle Icon
                                    if (isSelected && widget.isEditable)
                                      Positioned(
                                        right: -10,
                                        bottom: -10,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              final dw = details.delta.dx / scaleX;
                                              final dh = details.delta.dy / scaleY;
                                              line.customWidth = ((line.customWidth ?? line.box.width) + dw)
                                                  .clamp(30.0, nativeW.toDouble());
                                              line.customHeight = ((line.customHeight ?? line.box.height) + dh)
                                                  .clamp(14.0, nativeH.toDouble());
                                            });
                                            widget.onLineUpdated?.call(line);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: const [
                                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.open_in_full_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
