import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:xscan/core/services/app_storage.dart';

class _BatchItem {
  _BatchItem({required this.name, required this.content, this.type = 'text'});
  final String name;
  final String content;
  final String type;
}

class BatchQrScreen extends StatefulWidget {
  const BatchQrScreen({super.key});

  @override
  State<BatchQrScreen> createState() => _BatchQrScreenState();
}

class _BatchQrScreenState extends State<BatchQrScreen> {
  List<_BatchItem> _items = [];
  bool _generating = false;
  double _progress = 0;
  String? _fileName;
  bool _saveAsPdf = false;

  Future<void> _pickCsv() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (file == null) return;
    final content = await File(file.path).readAsString();
    final rows = const CsvToListConverter().convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) return;

    final items = <_BatchItem>[];
    for (final row in rows) {
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;
      final cols = row.map((e) => e.toString().trim()).toList();
      if (cols.length >= 3) {
        items.add(_BatchItem(name: cols[0], type: cols[1], content: cols[2]));
      } else if (cols.length == 2) {
        items.add(_BatchItem(name: cols[0], content: cols[1]));
      } else {
        items.add(_BatchItem(name: 'item_${items.length + 1}', content: cols[0]));
      }
    }
    setState(() {
      _items = items;
      _fileName = file.name;
    });
  }

  Future<ui.Image> _renderQr(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    return painter.toImage(512);
  }

  Future<Uint8List?> _qrPng(String data) async {
    final image = await _renderQr(data);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _generateAll() async {
    if (_items.isEmpty) return;
    setState(() {
      _generating = true;
      _progress = 0;
    });

    if (_saveAsPdf) {
      await _generateAsPdf();
    } else {
      await _generateAsPngs();
    }

    if (!mounted) return;
    setState(() {
      _generating = false;
      _progress = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Batch generation complete')),
    );
  }

  Future<void> _generateAsPngs() async {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final bytes = await _qrPng(item.content);
      if (bytes != null) {
        await AppStorage.writeExport('${item.name}.png', bytes);
      }
      if (!mounted) return;
      setState(() => _progress = (i + 1) / _items.length);
    }
  }

  Future<void> _generateAsPdf() async {
    final pdf = PdfDocument();
    pdf.pageSettings.size = const Size(595, 842);
    final pages = <_PdfPageData>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final bytes = await _qrPng(item.content);
      pages.add(_PdfPageData(item: item, qrBytes: bytes));
      if (!mounted) return;
      setState(() => _progress = (i + 1) / _items.length);
    }

    for (final pd in pages) {
      final page = pdf.pages.add();
      final g = page.graphics;

      if (pd.qrBytes != null) {
        final img = PdfBitmap(pd.qrBytes!);
        g.drawImage(img, const Rect.fromLTWH(197, 60, 200, 200));
      }

      final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
      g.drawString(
        pd.item.name,
        titleFont,
        bounds: const Rect.fromLTWH(0, 280, 595, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      g.drawString(
        pd.item.content,
        bodyFont,
        bounds: const Rect.fromLTWH(40, 320, 515, 80),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final typeFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);
      g.drawString(
        'Type: ${pd.item.type}',
        typeFont,
        bounds: const Rect.fromLTWH(0, 420, 595, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    final bytes = await pdf.save();
    pdf.dispose();
    await AppStorage.writeExport('batch_qr.pdf', bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch QR Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _generating ? null : _pickCsv,
            icon: const Icon(Icons.upload_file),
            label: const Text('Pick CSV File'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Text(_fileName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Save as PDF with labels'),
              const Spacer(),
              Switch(
                value: _saveAsPdf,
                onChanged: (v) => setState(() => _saveAsPdf = v),
              ),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${_items.length} items loaded', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._items.map((item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.qr_code_2, size: 32),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(item.type, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                )),
            const SizedBox(height: 16),
            if (_generating) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Center(child: Text('${(_progress * 100).toInt()}%')),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generating ? null : _generateAll,
              icon: const Icon(Icons.qr_code),
              label: Text(_generating ? 'Generating...' : 'Generate All'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfPageData {
  _PdfPageData({required this.item, this.qrBytes});
  final _BatchItem item;
  final Uint8List? qrBytes;
}
