import 'dart:async';
import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/core/services/barcode_utils.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';

enum ScanMode { document, barcode, ocr }

class ScannerScreen extends ConsumerStatefulWidget {
  final ScanMode initialMode;

  const ScannerScreen({super.key, this.initialMode = ScanMode.document});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _BatchItem {
  _BatchItem(this.value, this.format, {this.timestamp});
  final String value;
  final String format;
  final DateTime? timestamp;
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [],
  );
  bool _isFlashOn = false;
  bool _isBottomSheetOpen = false;
  bool _isProcessing = false;
  bool _continuous = false;
  double _zoom = 0;
  final List<_BatchItem> _batch = [];
  final Set<String> _seen = {};
  late ScanMode _mode = widget.initialMode;
  TextRecognitionScript _ocrScript = TextRecognitionScript.latin;

  // Animation
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  // Last scan result for overlay
  String? _lastScanValue;
  String? _lastScanFormat;
  BarcodeContentKind? _lastScanKind;
  bool _showResultOverlay = false;

  bool get _isBarcode => _mode == ScanMode.barcode;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    cameraController.dispose();
    super.dispose();
  }

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
                _buildTopBar(),
                const Spacer(),
                if (_isBarcode) ...[
                  _buildScanFrame(),
                  const Spacer(),
                  _buildBarcodeControls(),
                ],
                _buildModeSelector(),
              ],
            ),
          ),

          // Scan result overlay
          if (_showResultOverlay && _lastScanValue != null)
            _buildResultOverlay(),

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

  // ──────────────────── Top Bar ────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'Close scanner',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isBarcode)
            Row(
              children: [
                // Batch count badge
                if (_batch.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_batch.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Semantics(
                  label: 'Scan from gallery',
                  button: true,
                  child: IconButton(
                    tooltip: 'Scan from gallery',
                    icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
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
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: () => cameraController.switchCamera(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ──────────────────── Animated Scan Frame ────────────────────

  Widget _buildScanFrame() {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: AnimatedBuilder(
          animation: _scanLineAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _ScanFramePainter(
                animationValue: _scanLineAnimation.value,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: child,
            );
          },
          child: null,
        ),
      ),
    );
  }

  // ──────────────────── Barcode Controls ────────────────────

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
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _exportBatch,
                      icon: const Icon(Icons.file_download, size: 18),
                      label: const Text('Export', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saveBatch,
                      icon: const Icon(Icons.save),
                      label: Text('Save ${_batch.length}'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────── Mode Selector ────────────────────

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.black54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeChip('Document', ScanMode.document, Icons.document_scanner),
          _buildModeChip('QR/Barcode', ScanMode.barcode, Icons.qr_code_scanner),
          _buildModeChip('OCR Text', ScanMode.ocr, Icons.text_fields),
          if (_mode == ScanMode.ocr)
            IconButton(
              tooltip: 'OCR Language',
              icon: const Icon(Icons.translate, color: Colors.white, size: 20),
              onPressed: _showLanguagePicker,
            ),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('OCR Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...OcrService.scripts.entries.map((entry) => ListTile(
                  leading: Icon(
                    _ocrScript == entry.value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _ocrScript == entry.value ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(entry.key),
                  onTap: () {
                    setState(() => _ocrScript = entry.value);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String title, ScanMode mode, IconData icon) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── Result Overlay ────────────────────

  Widget _buildResultOverlay() {
    if (!_showResultOverlay || _lastScanValue == null) {
      return const SizedBox.shrink();
    }
    final kind = _lastScanKind ?? BarcodeContentKind.text;
    final isUrl = kind == BarcodeContentKind.url;
    final isWifi = kind == BarcodeContentKind.wifi;
    final isPhone = kind == BarcodeContentKind.phone;
    final isEmail = kind == BarcodeContentKind.email;
    final isSms = kind == BarcodeContentKind.sms;
    final isLocation = kind == BarcodeContentKind.location;

    return Positioned(
      bottom: 140,
      left: 16,
      right: 16,
      child: AnimatedSlide(
        offset: _showResultOverlay ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _showResultOverlay ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _lastScanFormat ?? 'Barcode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _contentTypeLabel(kind),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => setState(() => _showResultOverlay = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _lastScanValue ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isUrl) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openScannedUrl,
                          icon: const Icon(Icons.open_in_browser, size: 16),
                          label: const Text('Open', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isWifi)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _connectWifi,
                          icon: const Icon(Icons.wifi, size: 16),
                          label: const Text('Connect', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (isWifi) const SizedBox(width: 8),
                    if (isPhone)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openPhone,
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('Call', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (isPhone) const SizedBox(width: 8),
                    if (isEmail)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openEmail,
                          icon: const Icon(Icons.email, size: 16),
                          label: const Text('Email', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (isEmail) const SizedBox(width: 8),
                    if (isSms)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openSms,
                          icon: const Icon(Icons.sms, size: 16),
                          label: const Text('SMS', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (isSms) const SizedBox(width: 8),
                    if (isLocation)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openLocation,
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('Map', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (isLocation) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyScannedValue,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saveScannedBarcode,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Document Launcher ────────────────────

  Widget _buildDocumentLauncher() {
    final isOcr = _mode == ScanMode.ocr;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOcr ? Icons.text_snippet_outlined : Icons.document_scanner_outlined,
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
              isOcr
                  ? 'Take a photo or pick from gallery — text will be extracted automatically using on-device OCR.'
                  : 'Point at a page — edges are detected automatically. '
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open Scanner'),
              ),
            ),
            const SizedBox(height: 16),
            // Quick gallery pick for OCR
            if (isOcr)
              TextButton.icon(
                onPressed: _isProcessing ? null : _ocrFromGallery,
                icon: const Icon(Icons.photo_library_outlined, color: Colors.white70),
                label: const Text('Pick from Gallery',
                    style: TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Barcode Detection ────────────────────

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
        _batch.add(_BatchItem(value, BarcodeUtils.semanticType(b), timestamp: DateTime.now()));
        added++;
      }
      if (added > 0) {
        HapticFeedback.mediumImpact();
        setState(() {});
      }
      return;
    }

    if (_isBottomSheetOpen) return;

    // Show inline overlay instead of bottom sheet
    final b = barcodes.first;
    if (b.rawValue != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _lastScanValue = b.rawValue;
        _lastScanFormat = BarcodeUtils.semanticType(b);
        _lastScanKind = BarcodeUtils.contentKind(b.rawValue!);
        _showResultOverlay = true;
      });
    }
  }

  Future<void> _openScannedUrl() async {
    if (_lastScanValue == null) return;
    final uri = Uri.parse(_lastScanValue!);
    final safeSchemes = {'http', 'https'};
    if (!safeSchemes.contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported scheme: ${uri.scheme}')),
      );
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app found to open this link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e')),
        );
      }
    }
  }

  String _contentTypeLabel(BarcodeContentKind kind) {
    switch (kind) {
      case BarcodeContentKind.url:
        return 'URL';
      case BarcodeContentKind.wifi:
        return 'WiFi';
      case BarcodeContentKind.email:
        return 'Email';
      case BarcodeContentKind.phone:
        return 'Phone';
      case BarcodeContentKind.sms:
        return 'SMS';
      case BarcodeContentKind.contact:
        return 'Contact';
      case BarcodeContentKind.event:
        return 'Event';
      case BarcodeContentKind.location:
        return 'Location';
      case BarcodeContentKind.crypto:
        return 'Crypto';
      case BarcodeContentKind.text:
        return 'Text';
    }
  }

  /// Parses a WiFi QR string like WIFI:S:MyNetwork;T:WPA;P:password;;
  /// and launches the Android WiFi settings panel.
  Future<void> _connectWifi() async {
    if (_lastScanValue == null) return;
    final v = _lastScanValue!;
    // Parse WiFi QR fields
    final ssid = _extractWifiField(v, 'S');
    final password = _extractWifiField(v, 'P');

    if (ssid == null || ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read WiFi network name')),
      );
      return;
    }

    // Android doesn't have a direct "connect to WiFi" intent that accepts
    // SSID/password programmatically without special permissions.
    // The best UX is to copy the SSID+password and open WiFi settings.
    final creds = password != null ? 'SSID: $ssid\nPassword: $password' : 'SSID: $ssid';
    Clipboard.setData(ClipboardData(text: creds));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(password != null
              ? 'WiFi credentials copied. Paste in WiFi settings.'
              : 'WiFi name copied.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _extractWifiField(String wifi, String field) {
    final regex = RegExp('$field:([^;]*)', caseSensitive: false);
    final match = regex.firstMatch(wifi);
    return match?.group(1);
  }

  Future<void> _openPhone() async {
    if (_lastScanValue == null) return;
    final uri = Uri.parse(_lastScanValue!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openEmail() async {
    if (_lastScanValue == null) return;
    final v = _lastScanValue!;
    // mailto:user@example.com?subject=...&body=...
    // or MATMSG:TO:user@example.com;SUB:subject;BODY:body;;
    if (v.toLowerCase().startsWith('mailto:')) {
      final uri = Uri.parse(v);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else if (v.toLowerCase().startsWith('matmsg:')) {
      // Parse MATMSG format
      final to = _extractMatMsgField(v, 'TO');
      final sub = _extractMatMsgField(v, 'SUB');
      final body = _extractMatMsgField(v, 'BODY');
      if (to != null) {
        final params = <String, String>{};
        if (sub != null) params['subject'] = sub;
        if (body != null) params['body'] = body;
        final uri = Uri(scheme: 'mailto', path: to, queryParameters: params);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } else {
      // Plain email address
      final uri = Uri(scheme: 'mailto', path: v);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  String? _extractMatMsgField(String msg, String field) {
    final regex = RegExp('$field:([^;]*)', caseSensitive: false);
    final match = regex.firstMatch(msg);
    return match?.group(1)?.trim();
  }

  Future<void> _openSms() async {
    if (_lastScanValue == null) return;
    final uri = Uri.parse(_lastScanValue!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openLocation() async {
    if (_lastScanValue == null) return;
    final v = _lastScanValue!;
    // geo:lat,lon?q=lat,lon(label)
    if (v.toLowerCase().startsWith('geo:')) {
      final uri = Uri.parse(v);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // Try as plain coordinates
      final parts = v.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) {
          final uri = Uri.parse('geo:$lat,$lon');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    }
  }

  void _copyScannedValue() {
    if (_lastScanValue == null) return;
    Clipboard.setData(ClipboardData(text: _lastScanValue!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _saveScannedBarcode() async {
    if (_lastScanValue == null) return;
    final format = _lastScanFormat ?? 'Unknown';
    final kind = _lastScanKind ?? BarcodeContentKind.text;
    final isUrl = kind == BarcodeContentKind.url;

    final isarService = ref.read(isarServiceProvider);
    final newDoc = ScanDocument()
      ..title = isUrl ? 'Scanned Link' : 'Scanned $format'
      ..filePath = ''
      ..ocrText = _lastScanValue
      ..dateCreated = DateTime.now()
      ..category = 'Barcodes'
      ..fileType = 'barcode'
      ..barcodeFormat = format;

    await isarService.saveDocument(newDoc);
    if (!mounted) return;

    setState(() => _showResultOverlay = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to Barcodes!')),
    );
  }

  Future<void> _scanFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final capture = await cameraController.analyzeImage(file.path);
    if (!mounted) return;
    final barcodes = capture?.barcodes ?? [];
    if (barcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No barcode found in image')),
      );
      return;
    }
    if (barcodes.length > 1) {
      _showMultiSheet(barcodes);
    } else {
      final b = barcodes.first;
      if (b.rawValue != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _lastScanValue = b.rawValue;
          _lastScanFormat = BarcodeUtils.semanticType(b);
          _lastScanKind = BarcodeUtils.contentKind(b.rawValue!);
          _showResultOverlay = true;
        });
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _lastScanValue = b.rawValue;
                              _lastScanFormat = BarcodeUtils.semanticType(b);
                              _lastScanKind = BarcodeUtils.contentKind(b.rawValue!);
                              _showResultOverlay = true;
                            });
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

  // ──────────────────── Batch Operations ────────────────────

  Future<void> _saveBatch() async {
    if (_batch.isEmpty) return;
    final isarService = ref.read(isarServiceProvider);
    for (final item in _batch) {
      final doc = ScanDocument()
        ..title = 'Batch ${item.format}'
        ..filePath = ''
        ..ocrText = item.value
        ..dateCreated = item.timestamp ?? DateTime.now()
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportBatch() async {
    if (_batch.isEmpty) return;

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export Batch'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const ListTile(
              leading: Icon(Icons.table_chart),
              title: Text('Export as CSV'),
              subtitle: Text('Spreadsheet format'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: const ListTile(
              leading: Icon(Icons.text_snippet),
              title: Text('Export as Text'),
              subtitle: Text('Plain text file'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const ListTile(
              leading: Icon(Icons.share),
              title: Text('Share All'),
              subtitle: Text('Share via system sheet'),
            ),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (format == 'csv') {
      final buffer = StringBuffer('Value,Format,Timestamp\n');
      for (final item in _batch) {
        final ts = item.timestamp?.toIso8601String() ?? '';
        buffer.writeln('"${item.value}","${item.format}","$ts"');
      }
      final file = File('${dir.path}/barcode_batch_$timestamp.csv');
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${_batch.length} barcodes to CSV')),
      );
    } else if (format == 'txt') {
      final buffer = StringBuffer();
      for (var i = 0; i < _batch.length; i++) {
        final item = _batch[i];
        buffer.writeln('[${i + 1}] ${item.format}: ${item.value}');
      }
      final file = File('${dir.path}/barcode_batch_$timestamp.txt');
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${_batch.length} barcodes to text')),
      );
    } else if (format == 'share') {
      final buffer = StringBuffer();
      for (var i = 0; i < _batch.length; i++) {
        final item = _batch[i];
        buffer.writeln('[${i + 1}] ${item.format}: ${item.value}');
      }
      final file = File('${dir.path}/barcode_batch_$timestamp.txt');
      await file.writeAsString(buffer.toString());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Scanned barcodes (${_batch.length})',
      ));
    }
  }

  // ──────────────────── Document Scanner ────────────────────

  Future<void> _launchDocumentScanner() async {
    List<String>? pictures;
    try {
      pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 50,
        scannerSource: ScannerSource.cameraAndGallery,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanner error: $e')),
      );
      return;
    }

    if (pictures == null || pictures.isEmpty || !mounted) return;

    // Show preview before saving
    final confirmed = await _showPagePreview(pictures);
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final persistedPaths = <String>[];
      for (final path in pictures) {
        persistedPaths.add(await AppStorage.persistPage(path));
      }

      final ocrService = OcrService(script: _ocrScript);
      final buffer = StringBuffer();
      for (var i = 0; i < persistedPaths.length; i++) {
        final text = await ocrService.extractTextFromImage(persistedPaths[i]);
        if (text == null || text.trim().isEmpty) continue;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${persistedPaths.length} page(s) to $category')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save scan: $e')),
      );
    }
  }

  Future<bool> _showPagePreview(List<String> pages) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PagePreviewDialog(pages: pages),
    ) ?? false;
  }

  // ──────────────────── OCR from Gallery ────────────────────

  Future<void> _ocrFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final persistedPath = await AppStorage.persistPage(file.path);
      final ocrService = OcrService(script: _ocrScript);
      final text = await ocrService.extractTextFromImage(persistedPath);
      ocrService.dispose();

      if (!mounted) return;

      if (text == null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR failed - the image could not be processed')),
        );
        return;
      }
      if (text.trim().isEmpty) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in image')),
        );
        return;
      }

      final newDoc = ScanDocument()
        ..title = 'OCR ${DateTime.now().toLocal().toString().split('.')[0]}'
        ..filePath = persistedPath
        ..ocrText = text
        ..dateCreated = DateTime.now()
        ..fileType = 'scan'
        ..category = 'Notes';

      await ref.read(isarServiceProvider).saveDocument(newDoc);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text extracted and saved to Notes')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    }
  }
}

// ──────────────────── Scan Frame Painter ────────────────────

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.animationValue, required this.color});

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );
    canvas.drawRRect(rrect, paint);

    // Corner accents
    final cornerLen = size.width * 0.15;
    final path = Path()
      // Top-left
      ..moveTo(0, cornerLen)
      ..lineTo(0, 0)
      ..lineTo(cornerLen, 0)
      // Top-right
      ..moveTo(size.width - cornerLen, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerLen)
      // Bottom-right
      ..moveTo(size.width, size.height - cornerLen)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - cornerLen, size.height)
      // Bottom-left
      ..moveTo(cornerLen, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - cornerLen);
    canvas.drawPath(path, cornerPaint);

    // Scanning line
    final lineY = size.height * animationValue;
    final lineRect = Rect.fromLTWH(10, lineY - 1, size.width - 20, 2);
    canvas.drawRect(lineRect, linePaint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) => old.animationValue != animationValue;
}

// ──────────────────── Page Preview Dialog ────────────────────

class _PagePreviewDialog extends StatefulWidget {
  const _PagePreviewDialog({required this.pages});
  final List<String> pages;

  @override
  State<_PagePreviewDialog> createState() => _PagePreviewDialogState();
}

class _PagePreviewDialogState extends State<_PagePreviewDialog> {
  late List<String> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.pages);
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Preview (${_pages.length} pages)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _pages.isEmpty
            ? const Center(child: Text('No pages remaining'))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                itemBuilder: (ctx, i) {
                  return Stack(
                    children: [
                      Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_pages[i]),
                                  fit: BoxFit.cover,
                                  width: 160,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Page ${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removePage(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _pages.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: Text('Save ${_pages.length} Pages'),
        ),
      ],
    );
  }
}
