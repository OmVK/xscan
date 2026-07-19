import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

class PdfToQrScreen extends StatefulWidget {
  const PdfToQrScreen({super.key});

  @override
  State<PdfToQrScreen> createState() => _PdfToQrScreenState();
}

class _PdfToQrScreenState extends State<PdfToQrScreen> {
  String? _pdfPath;
  int _pageCount = 0;
  int _selectedPage = 0;
  String _extractedText = '';
  String _qrData = '';
  bool _loading = false;

  String _extractPageText(String path, int pageIndex) {
    try {
      final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
      final extractor = PdfTextExtractor(doc);
      final text = extractor.extractText();
      doc.dispose();
      return text;
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickPdf() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (file == null) return;
    final path = file.path;

    setState(() {
      _loading = true;
      _pdfPath = path;
      _qrData = '';
      _extractedText = '';
    });

    try {
      final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
      _pageCount = doc.pages.count;
      doc.dispose();
    } catch (_) {
      _pageCount = 0;
    }

    if (_pageCount > 0) {
      _selectedPage = 0;
      await _extract();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _extract() async {
    if (_pdfPath == null) return;
    setState(() => _loading = true);
    final text = _extractPageText(_pdfPath!, _selectedPage);
    if (!mounted) return;
    setState(() {
      _extractedText = text;
      _qrData = text;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_qrData.isEmpty) return;
    final painter = QrPainter(
      data: _qrData,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    );
    final image = await painter.toImage(512);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;
    final bytes = byteData.buffer.asUint8List();
    final path = await AppStorage.writeExport('pdf_page_qr.png', bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $path')));
  }

  Future<void> _share() async {
    if (_qrData.isEmpty) return;
    final painter = QrPainter(
      data: _qrData,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    );
    final image = await painter.toImage(512);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;
    final bytes = byteData.buffer.asUint8List();
    final path = await AppStorage.writeExport('pdf_page_qr.png', bytes);
    await ToolIO.share(path, text: 'QR Code from PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to QR'),
        actions: [
          if (_qrData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in QR Generator',
              onPressed: () {
                Navigator.pushNamed(context, '/qr-generator', arguments: _qrData);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _pickPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Pick PDF File'),
          ),
          if (_pdfPath != null) ...[
            const SizedBox(height: 8),
            Text(
              _pdfPath!.split(Platform.pathSeparator).last,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (_pageCount > 1) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Page: '),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _selectedPage.toDouble(),
                    min: 0,
                    max: (_pageCount - 1).toDouble(),
                    divisions: _pageCount - 1,
                    label: '${_selectedPage + 1} / $_pageCount',
                    onChanged: (v) {
                      setState(() => _selectedPage = v.toInt());
                      _extract();
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_selectedPage + 1} / $_pageCount',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
          if (_extractedText.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Extracted Text', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _extractedText.length > 500
                    ? '${_extractedText.substring(0, 500)}...'
                    : _extractedText,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_extractedText.length} characters',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          if (_qrData.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 240,
                gapless: true,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.download),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
