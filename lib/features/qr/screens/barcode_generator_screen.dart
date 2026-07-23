import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum BarcodeType {
  code128,
  code39,
  code93,
  ean13,
  ean8,
  upcA,
  upcE,
  codabar,
  itf,
  isbn,
}

class _BarcodeTypeInfo {
  const _BarcodeTypeInfo(this.type, this.label, this.description, this.validator);
  final BarcodeType type;
  final String label;
  final String description;
  final String? Function(String)? validator;
}

String? _validateEan13(String v) {
  if (!RegExp(r'^\d{12,13}$').hasMatch(v)) return 'Enter 12 or 13 digits';
  return null;
}

String? _validateEan8(String v) {
  if (!RegExp(r'^\d{7,8}$').hasMatch(v)) return 'Enter 7 or 8 digits';
  return null;
}

String? _validateUpcA(String v) {
  if (!RegExp(r'^\d{11,12}$').hasMatch(v)) return 'Enter 11 or 12 digits';
  return null;
}

String? _validateUpcE(String v) {
  if (!RegExp(r'^\d{6,8}$').hasMatch(v)) return 'Enter 6 to 8 digits';
  return null;
}

String? _validateDigits(String v) {
  if (!RegExp(r'^\d+$').hasMatch(v)) return 'Only digits allowed';
  return null;
}

String? _validateIsbn(String v) {
  if (!RegExp(r'^(?:\d{10}|\d{13})$').hasMatch(v)) return 'Enter 10 or 13 digits';
  return null;
}

const _barcodeTypes = <_BarcodeTypeInfo>[
  _BarcodeTypeInfo(BarcodeType.code128, 'Code 128', 'Alphanumeric, high density', null),
  _BarcodeTypeInfo(BarcodeType.code39, 'Code 39', 'Alphanumeric, uppercase + digits', null),
  _BarcodeTypeInfo(BarcodeType.code93, 'Code 93', 'Like Code 39 but denser', null),
  _BarcodeTypeInfo(BarcodeType.ean13, 'EAN-13', 'Product barcode (13 digits)', _validateEan13),
  _BarcodeTypeInfo(BarcodeType.ean8, 'EAN-8', 'Small product barcode (8 digits)', _validateEan8),
  _BarcodeTypeInfo(BarcodeType.upcA, 'UPC-A', 'US product barcode (12 digits)', _validateUpcA),
  _BarcodeTypeInfo(BarcodeType.upcE, 'UPC-E', 'Compressed UPC (6-8 digits)', _validateUpcE),
  _BarcodeTypeInfo(BarcodeType.codabar, 'Codabar', 'Numeric, library/medical', _validateDigits),
  _BarcodeTypeInfo(BarcodeType.itf, 'ITF', 'Interleaved 2 of 5, numeric pairs', _validateDigits),
  _BarcodeTypeInfo(BarcodeType.isbn, 'ISBN', 'Book identifier (10 or 13 digits)', _validateIsbn),
];

class BarcodeGeneratorScreen extends StatefulWidget {
  const BarcodeGeneratorScreen({super.key});

  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  BarcodeType _selectedType = BarcodeType.code128;
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _barcodeKey = GlobalKey();
  double _height = 120;
  double _barWidth = 2.0;
  bool _showText = true;
  Color _fgColor = Colors.black;
  Color _bgColor = Colors.white;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Barcode _getBarcode() {
    switch (_selectedType) {
      case BarcodeType.code128:
        return Barcode.code128();
      case BarcodeType.code39:
        return Barcode.code39();
      case BarcodeType.code93:
        return Barcode.code93();
      case BarcodeType.ean13:
        return Barcode.ean13();
      case BarcodeType.ean8:
        return Barcode.ean8();
      case BarcodeType.upcA:
        return Barcode.upcA();
      case BarcodeType.upcE:
        return Barcode.upcE();
      case BarcodeType.codabar:
        return Barcode.codabar();
      case BarcodeType.itf:
        return Barcode.itf();
      case BarcodeType.isbn:
        return Barcode.isbn();
    }
  }

  void _validate() {
    final info = _barcodeTypes.firstWhere((t) => t.type == _selectedType);
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter data to encode');
      return;
    }
    if (info.validator != null) {
      setState(() => _error = info.validator!(text));
    } else {
      setState(() => _error = null);
    }
  }

  bool get _isValid => _error == null && _textController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_isValid) return;
    try {
      final boundary = _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  Future<void> _share() async {
    if (!_isValid) return;
    try {
      final boundary = _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/barcode.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Barcode: ${_textController.text}'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _barcodeTypes.firstWhere((t) => t.type == _selectedType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Generator'),
        actions: [
          if (_isValid)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _share,
              tooltip: 'Share',
            ),
          if (_isValid)
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _save,
              tooltip: 'Save',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Barcode preview
          Container(
            constraints: const BoxConstraints(minHeight: 200),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: _isValid
                  ? RepaintBoundary(
                      key: _barcodeKey,
                      child: BarcodeWidget(
                        barcode: _getBarcode(),
                        data: _textController.text.trim(),
                        width: (MediaQuery.of(context).size.width - 80) * (_barWidth / 2.0),
                        height: _height,
                        color: _fgColor,
                        drawText: _showText,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 64,
                            color: theme.colorScheme.outline.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enter data to preview',
                            style: TextStyle(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Barcode type selector
          Text(
            'Barcode Type',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _barcodeTypes.map((bt) {
              final selected = bt.type == _selectedType;
              return ChoiceChip(
                label: Text(bt.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedType = bt.type;
                    _error = null;
                  });
                  _validate();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            info.description,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),

          const SizedBox(height: 20),

          // Data input
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: 'Barcode Data',
              hintText: _getHintText(),
              errorText: _error,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.data_object),
            ),
            onChanged: (_) => _validate(),
          ),

          const SizedBox(height: 20),

          // Height slider
          Row(
            children: [
              const Icon(Icons.height, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _height,
                  min: 60,
                  max: 250,
                  divisions: 19,
                  label: '${_height.round()} px',
                  onChanged: (v) => setState(() => _height = v),
                ),
              ),
              Text('${_height.round()}px', style: const TextStyle(fontSize: 12)),
            ],
          ),

          // Bar width slider
          Row(
            children: [
              const Icon(Icons.swipe, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _barWidth,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  label: _barWidth.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _barWidth = v),
                ),
              ),
              Text('${_barWidth.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12)),
            ],
          ),

          // Show text toggle
          SwitchListTile(
            title: const Text('Show text below barcode'),
            value: _showText,
            onChanged: (v) => setState(() => _showText = v),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),

          // Color pickers
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Foreground'),
                  trailing: CircleAvatar(backgroundColor: _fgColor, radius: 16),
                  onTap: () => _pickColor(isForeground: true),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('Background'),
                  trailing: CircleAvatar(backgroundColor: _bgColor, radius: 16),
                  onTap: () => _pickColor(isForeground: false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons
          if (_isValid) ...[
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_alt),
              label: const Text('Save as PNG'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ],
      ),
    );
  }

  String _getHintText() {
    switch (_selectedType) {
      case BarcodeType.code128:
      case BarcodeType.code39:
      case BarcodeType.code93:
        return 'e.g. Hello-123';
      case BarcodeType.ean13:
        return 'e.g. 5901234123457';
      case BarcodeType.ean8:
        return 'e.g. 96385074';
      case BarcodeType.upcA:
        return 'e.g. 123456789012';
      case BarcodeType.upcE:
        return 'e.g. 01234565';
      case BarcodeType.codabar:
        return 'e.g. A12345B';
      case BarcodeType.itf:
        return 'e.g. 1234567890';
      case BarcodeType.isbn:
        return 'e.g. 9781234567897';
    }
  }

  Future<void> _pickColor({required bool isForeground}) async {
    final colors = [
      Colors.black, Colors.white, Colors.red, Colors.blue,
      Colors.green, Colors.orange, Colors.purple, Colors.teal,
      Colors.indigo, Colors.brown, Colors.pink, Colors.grey,
    ];

    final picked = await showModalBottomSheet<Color>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isForeground ? 'Foreground Color' : 'Background Color',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.outline,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        if (isForeground) {
          _fgColor = picked;
        } else {
          _bgColor = picked;
        }
      });
    }
  }
}
