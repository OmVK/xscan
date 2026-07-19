import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/barcode_utils.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';

enum ScanMode { document, barcode, ocr }

class ScannerScreen extends ConsumerStatefulWidget {
  final ScanMode initialMode;

  const ScannerScreen({super.key, this.initialMode = ScanMode.document});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _BatchItem {
  _BatchItem(this.value, this.format);
  final String value;
  final String format;
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [], // empty = all supported formats
  );
  bool _isFlashOn = false;
  bool _isBottomSheetOpen = false;
  bool _isProcessing = false;
  bool _continuous = false;
  double _zoom = 0;
  final List<_BatchItem> _batch = [];
  final Set<String> _seen = {};
  late ScanMode _mode = widget.initialMode;

  bool get _isBarcode => _mode == ScanMode.barcode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isBarcode)
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            )
          else
            _buildDocumentLauncher(),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        label: 'Close scanner',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      if (_isBarcode)
                        Row(
                          children: [
                            Semantics(
                              label: 'Scan from gallery',
                              button: true,
                              child: IconButton(
                                tooltip: 'Scan from gallery',
                                icon: const Icon(Icons.photo_library_outlined,
                                    color: Colors.white),
                                onPressed: _scanFromGallery,
                              ),
                            ),
                            Semantics(
                              label: _isFlashOn ? 'Flashlight on' : 'Flashlight off',
                              button: true,
                              child: IconButton(
                                tooltip: 'Flashlight',
                                icon: Icon(
                                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  cameraController.toggleTorch();
                                  setState(() => _isFlashOn = !_isFlashOn);
                                },
                              ),
                            ),
                            Semantics(
                              label: 'Switch camera',
                              button: true,
                              child: IconButton(
                                tooltip: 'Switch camera',
                                icon: const Icon(Icons.cameraswitch,
                                    color: Colors.white),
                                onPressed: () => cameraController.switchCamera(),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isBarcode) _buildScanFrame(),
                const Spacer(),
                if (_isBarcode) _buildBarcodeControls(),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeSelector('Document', ScanMode.document),
                      _buildModeSelector('QR/Barcode', ScanMode.barcode),
                      _buildModeSelector('OCR Text', ScanMode.ocr),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Semantics(
              label: 'Processing',
              liveRegion: true,
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildBarcodeControls() {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
              Expanded(
                child: Slider(
                  value: _zoom,
                  onChanged: (v) {
                    setState(() => _zoom = v);
                    cameraController.setZoomScale(v);
                  },
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: _continuous,
                    onChanged: (v) => setState(() => _continuous = v),
                  ),
                  const Text('Continuous / batch',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
              if (_batch.isNotEmpty)
                FilledButton.icon(
                  onPressed: _saveBatch,
                  icon: const Icon(Icons.save),
                  label: Text('Save ${_batch.length}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_mode != ScanMode.barcode) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    if (_continuous) {
      var added = 0;
      for (final b in barcodes) {
        final value = b.rawValue;
        if (value == null || _seen.contains(value)) continue;
        _seen.add(value);
        _batch.add(_BatchItem(value, BarcodeUtils.semanticType(b)));
        added++;
      }
      if (added > 0) {
        HapticFeedback.mediumImpact();
        setState(() {});
      }
      return;
    }

    if (_isBottomSheetOpen) return;
    if (barcodes.length > 1) {
      _showMultiSheet(barcodes);
    } else {
      final b = barcodes.first;
      if (b.rawValue != null) {
        _showBarcodeBottomSheet(b.rawValue!, BarcodeUtils.semanticType(b));
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final capture = await cameraController.analyzeImage(file.path);
    if (!mounted) return;
    final barcodes = capture?.barcodes ?? [];
    if (barcodes.isEmpty) {
      final msg = 'No barcode found in image';
      SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
    if (barcodes.length > 1) {
      _showMultiSheet(barcodes);
    } else {
      final b = barcodes.first;
      if (b.rawValue != null) {
        _showBarcodeBottomSheet(b.rawValue!, BarcodeUtils.semanticType(b));
      }
    }
  }

  void _showMultiSheet(List<Barcode> barcodes) {
    if (_isBottomSheetOpen) return;
    _isBottomSheetOpen = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${barcodes.length} codes detected',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: barcodes
                    .where((b) => b.rawValue != null)
                    .map((b) => ListTile(
                          leading: const Icon(Icons.qr_code_2),
                          title: Text(b.rawValue!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(BarcodeUtils.semanticType(b)),
                          onTap: () {
                            Navigator.pop(context);
                            _showBarcodeBottomSheet(
                                b.rawValue!, BarcodeUtils.semanticType(b));
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _isBottomSheetOpen = false;
      });
    });
  }

  Future<void> _saveBatch() async {
    if (_batch.isEmpty) return;
    final isarService = ref.read(isarServiceProvider);
    for (final item in _batch) {
      final doc = ScanDocument()
        ..title = 'Batch ${item.format}'
        ..filePath = ''
        ..ocrText = item.value
        ..dateCreated = DateTime.now()
        ..category = 'Barcodes'
        ..fileType = 'barcode'
        ..barcodeFormat = item.format;
      await isarService.saveDocument(doc);
    }
    if (!mounted) return;
    final count = _batch.length;
    setState(() {
      _batch.clear();
      _seen.clear();
    });
    final msg = 'Saved $count barcodes';
    SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildDocumentLauncher() {
    final isOcr = _mode == ScanMode.ocr;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOcr
                  ? Icons.text_snippet_outlined
                  : Icons.document_scanner_outlined,
              size: 96,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 24),
            Text(
              isOcr ? 'Extract Text (OCR)' : 'Scan Document',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Point at a page — edges are detected automatically. '
              'Tap the shutter to capture and add multiple pages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Open scanner',
              button: true,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _launchDocumentScanner,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open Scanner'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(String title, ScanMode mode) {
    final isSelected = _mode == mode;
    return Semantics(
      label: 'Scan mode: $title',
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: () {
          if (_mode == mode) return;
          setState(() => _mode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchDocumentScanner() async {
    List<String>? pictures;
    try {
      pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 50,
        scannerSource: ScannerSource.cameraAndGallery,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = 'Scanner error: $e';
      SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    if (pictures == null || pictures.isEmpty || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final persistedPaths = <String>[];
      for (final path in pictures) {
        persistedPaths.add(await AppStorage.persistPage(path));
      }

      final ocrService = OcrService();
      final buffer = StringBuffer();
      for (var i = 0; i < persistedPaths.length; i++) {
        final text = await ocrService.extractTextFromImage(persistedPaths[i]);
        if (text.trim().isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n\n--- Page ${i + 1} ---\n\n');
        buffer.write(text);
      }
      ocrService.dispose();

      final category = _mode == ScanMode.ocr ? 'Notes' : 'Documents';
      final newDoc = ScanDocument()
        ..title = 'Scan ${DateTime.now().toLocal().toString().split('.')[0]}'
        ..filePath = persistedPaths.first
        ..additionalFilePaths =
            persistedPaths.length > 1 ? persistedPaths.sublist(1) : null
        ..ocrText = buffer.toString()
        ..dateCreated = DateTime.now()
        ..fileType = 'scan'
        ..category = category;

      await ref.read(isarServiceProvider).saveDocument(newDoc);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _isProcessing = false);

      final msg = 'Saved ${persistedPaths.length} page(s) to $category';
      SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      final msg = 'Failed to save scan: $e';
      SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _showBarcodeBottomSheet(String value, String format) {
    if (_isBottomSheetOpen) return;
    _isBottomSheetOpen = true;

    final kind = BarcodeUtils.contentKind(value);
    final isUrl = kind == BarcodeContentKind.url;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2),
                const SizedBox(width: 8),
                Text(format,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  SelectableText(value, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            if (isUrl)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(value);
                    final safeSchemes = {'http', 'https'};
                    if (safeSchemes.contains(uri.scheme) &&
                        await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open Link'),
                ),
              ),
            if (isUrl) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  SemanticsService.sendAnnouncement(View.of(context), 'Copied to clipboard', TextDirection.ltr);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Text'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _saveBarcode(value, format, isUrl),
                icon: const Icon(Icons.save),
                label: const Text('Save for Later'),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _isBottomSheetOpen = false;
      });
    });
  }

  Future<void> _saveBarcode(String value, String format, bool isUrl) async {
    var favorite = false;
    final controller =
        TextEditingController(text: isUrl ? 'Scanned Link' : 'Scanned $format');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Save Barcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: favorite,
                onChanged: (v) => setLocal(() => favorite = v ?? false),
                title: const Text('Add to favorites'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (title != null && title.trim().isNotEmpty) {
      final isarService = ref.read(isarServiceProvider);
      final newDoc = ScanDocument()
        ..title = title.trim()
        ..filePath = ''
        ..ocrText = value
        ..dateCreated = DateTime.now()
        ..category = 'Barcodes'
        ..fileType = 'barcode'
        ..barcodeFormat = format
        ..isFavorite = favorite;

      await isarService.saveDocument(newDoc);
      if (!mounted) return;

      const msg = 'Saved to Barcodes!';
      SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
