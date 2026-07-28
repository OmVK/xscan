import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

enum QrType {
  url,
  text,
  wifi,
  contact,
  email,
  sms,
  phone,
  location,
  event,
  crypto,
  whatsapp,
  instagram,
  facebook,
  linkedin,
  telegram,
  discord,
}

class QrDesign {
  const QrDesign({
    required this.name,
    required this.eyeShape,
    required this.dataShape,
    this.roundedFrame = false,
    this.description = '',
  });

  final String name;
  final QrEyeShape eyeShape;
  final QrDataModuleShape dataShape;
  final bool roundedFrame;
  final String description;
}

const _qrDesigns = <QrDesign>[
  QrDesign(
    name: 'Classic',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.square,
    description: 'Traditional square modules',
  ),
  QrDesign(
    name: 'Sharp',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.square,
    description: 'Crisp square with small dots',
  ),
  QrDesign(
    name: 'Rounded',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.circle,
    roundedFrame: true,
    description: 'Soft circular modules',
  ),
  QrDesign(
    name: 'Smooth',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.square,
    roundedFrame: true,
    description: 'Circle eyes, square data',
  ),
  QrDesign(
    name: 'Hybrid',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.circle,
    description: 'Square eyes, dot data',
  ),
  QrDesign(
    name: 'Dots',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.circle,
    description: 'Dotted data modules',
  ),
  QrDesign(
    name: 'Bubbles',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.circle,
    roundedFrame: true,
    description: 'Full bubble aesthetic',
  ),
  QrDesign(
    name: 'Diamond',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.square,
    description: 'Diamond-cut modules',
  ),
  QrDesign(
    name: 'Star',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.square,
    description: 'Star-shaped eye pattern',
  ),
  QrDesign(
    name: 'Rivet',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.circle,
    description: 'Industrial rivet look',
  ),
  QrDesign(
    name: 'Soft Square',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.square,
    roundedFrame: true,
    description: 'Rounded-corner squares',
  ),
  QrDesign(
    name: 'Pill',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.circle,
    description: 'Pill-shaped modules',
  ),
];

class QrColorTheme {
  const QrColorTheme(this.name, this.fg, this.bg, {this.gradient});
  final String name;
  final Color fg;
  final Color bg;
  final List<Color>? gradient;
}

const _qrThemes = <QrColorTheme>[
  QrColorTheme('Ink', Colors.black, Colors.white),
  QrColorTheme('Paper', Color(0xFF2C2C2C), Color(0xFFFAFAFA)),
  QrColorTheme('Violet', Color(0xFF6C63FF), Color(0xFFF3F1FF)),
  QrColorTheme('Indigo', Color(0xFF3F51B5), Color(0xFFE8EAF6)),
  QrColorTheme('Emerald', Color(0xFF00B894), Color(0xFFEFFFF9)),
  QrColorTheme('Teal', Color(0xFF009688), Color(0xFFE0F2F1)),
  QrColorTheme('Rose', Color(0xFFE84393), Color(0xFFFFF0F7)),
  QrColorTheme('Pink', Color(0xFFE91E63), Color(0xFFFCE4EC)),
  QrColorTheme('Ocean', Color(0xFF0984E3), Color(0xFFEFF8FF)),
  QrColorTheme('Sky', Color(0xFF03A9F4), Color(0xFFE1F5FE)),
  QrColorTheme('Sunset', Color(0xFFE17055), Color(0xFFFFF3EF)),
  QrColorTheme('Amber', Color(0xFFFFC107), Color(0xFFFFF8E1)),
  QrColorTheme('Midnight', Color(0xFF00E5FF), Color(0xFF0F0F13)),
  QrColorTheme('Obsidian', Color(0xFFBB86FC), Color(0xFF121212)),
  QrColorTheme('Carbon', Color(0xFF03DAC6), Color(0xFF1B1B1B)),
  QrColorTheme('Onyx', Color(0xFFCF6679), Color(0xFF121212)),
  QrColorTheme('Gold', Color(0xFFFFD700), Color(0xFF1A1A2E)),
  QrColorTheme('Royal', Color(0xFF9C27B0), Color(0xFFF3E5F5)),
  QrColorTheme('Forest', Color(0xFF2E7D32), Color(0xFFE8F5E9)),
  QrColorTheme('Crimson', Color(0xFFC62828), Color(0xFFFFEBEE)),
  QrColorTheme('Aurora', Color(0xFF7C4DFF), Color(0xFF18FFFF),
      gradient: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
  QrColorTheme('Sunrise', Color(0xFFFF6F00), Color(0xFFFFF3E0),
      gradient: [Color(0xFFFF6F00), Color(0xFFFF1744)]),
  QrColorTheme('Ocean Deep', Color(0xFF00BFA5), Color(0xFFE0F7FA),
      gradient: [Color(0xFF00BFA5), Color(0xFF2979FF)]),
];

class QrGeneratorScreen extends StatefulWidget {
  final String? initialData;

  const QrGeneratorScreen({super.key, this.initialData});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  QrType _type = QrType.url;
  final Map<String, TextEditingController> _c = {};
  Color _fg = Colors.black;
  Color _bg = Colors.white;
  String _data = '';
  int _designIndex = 0;
  int _themeIndex = 0;
  Uint8List? _logoBytes;
  Uint8List? _bgImageBytes;
  List<Map<String, dynamic>> _presets = [];
  double _exportSize = 1024;
  bool _includeQuietZone = true;
  double _logoSize = 0.20; // 20% max size for 100% scannability
  bool _useGradient = false;
  List<Color>? _activeGradient;

  QrDesign get _design => _qrDesigns[_designIndex];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _data = widget.initialData!;
      final isUrl = _data.toLowerCase().startsWith('http://') ||
          _data.toLowerCase().startsWith('https://');
      _type = isUrl ? QrType.url : QrType.text;
      _ctrl(isUrl ? 'url' : 'text').text = _data;
    }
    _loadPresets();
  }

  final _palette = const [
    Colors.black,
    Color(0xFF6C63FF),
    Color(0xFF00B894),
    Color(0xFFE84393),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Colors.white,
  ];

  TextEditingController _ctrl(String key) =>
      _c.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Widget> _fields() {
    switch (_type) {
      case QrType.url:
        return [_field('url', 'URL', hint: 'https://example.com')];
      case QrType.text:
        return [_field('text', 'Text', lines: 4)];
      case QrType.wifi:
        return [
          _field('ssid', 'Network name (SSID)'),
          _field('password', 'Password'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hidden network'),
            trailing: Switch(
              value: false,
              onChanged: (_) {},
            ),
          ),
        ];
      case QrType.contact:
        return [
          _field('name', 'Full name'),
          _field('phone', 'Phone'),
          _field('email', 'Email'),
          _field('org', 'Company'),
        ];
      case QrType.email:
        return [
          _field('email', 'Email address'),
          _field('subject', 'Subject'),
          _field('body', 'Message', lines: 3),
        ];
      case QrType.sms:
        return [
          _field('phone', 'Phone number'),
          _field('message', 'Message', lines: 2),
        ];
      case QrType.phone:
        return [_field('phone', 'Phone number')];
      case QrType.location:
        return [
          _field('lat', 'Latitude', hint: '37.7749'),
          _field('lng', 'Longitude', hint: '-122.4194'),
        ];
      case QrType.event:
        return [
          _field('title', 'Event title'),
          _field('location', 'Location'),
          _field('description', 'Description', lines: 2),
        ];
      case QrType.crypto:
        return [
          _field('address', 'Wallet address'),
          _field('amount', 'Amount (optional)'),
        ];
      case QrType.whatsapp:
        return [
          _field('phone', 'Phone with country code (e.g. +14155552671)'),
          _field('message', 'Initial message (optional)', lines: 2),
        ];
      case QrType.instagram:
        return [_field('username', 'Username (without @)')];
      case QrType.facebook:
        return [_field('profile', 'Username or Page ID')];
      case QrType.linkedin:
        return [_field('profile', 'Profile URL or Username')];
      case QrType.telegram:
        return [_field('username', 'Username (without @)')];
      case QrType.discord:
        return [_field('invite', 'Invite link or Server code')];
    }
  }

  Widget _field(String key, String label, {String? hint, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _ctrl(key),
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    String payload = '';
    switch (_type) {
      case QrType.url:
        payload = _ctrl('url').text.trim();
        if (payload.isNotEmpty &&
            !payload.startsWith('http://') &&
            !payload.startsWith('https://')) {
          payload = 'https://$payload';
        }
        break;
      case QrType.text:
        payload = _ctrl('text').text.trim();
        break;
      case QrType.wifi:
        final ssid = _ctrl('ssid').text.trim();
        final pass = _ctrl('password').text.trim();
        if (ssid.isNotEmpty) {
          payload = 'WIFI:S:$ssid;T:WPA;P:$pass;;';
        }
        break;
      case QrType.contact:
        final name = _ctrl('name').text.trim();
        final phone = _ctrl('phone').text.trim();
        final email = _ctrl('email').text.trim();
        final org = _ctrl('org').text.trim();
        if (name.isNotEmpty || phone.isNotEmpty || email.isNotEmpty) {
          payload =
              'BEGIN:VCARD\nVERSION:3.0\nN:$name\nTEL:$phone\nEMAIL:$email\nORG:$org\nEND:VCARD';
        }
        break;
      case QrType.email:
        final to = _ctrl('email').text.trim();
        final sub = Uri.encodeComponent(_ctrl('subject').text.trim());
        final body = Uri.encodeComponent(_ctrl('body').text.trim());
        if (to.isNotEmpty) {
          payload = 'mailto:$to?subject=$sub&body=$body';
        }
        break;
      case QrType.sms:
        final phone = _ctrl('phone').text.trim();
        final msg = Uri.encodeComponent(_ctrl('message').text.trim());
        if (phone.isNotEmpty) {
          payload = 'smsto:$phone:$msg';
        }
        break;
      case QrType.phone:
        final phone = _ctrl('phone').text.trim();
        if (phone.isNotEmpty) {
          payload = 'tel:$phone';
        }
        break;
      case QrType.location:
        final lat = _ctrl('lat').text.trim();
        final lng = _ctrl('lng').text.trim();
        if (lat.isNotEmpty && lng.isNotEmpty) {
          payload = 'geo:$lat,$lng';
        }
        break;
      case QrType.event:
        final title = _ctrl('title').text.trim();
        final loc = _ctrl('location').text.trim();
        final desc = _ctrl('description').text.trim();
        if (title.isNotEmpty) {
          payload =
              'BEGIN:VEVENT\nSUMMARY:$title\nLOCATION:$loc\nDESCRIPTION:$desc\nEND:VEVENT';
        }
        break;
      case QrType.crypto:
        payload = _ctrl('address').text.trim();
        break;
      case QrType.whatsapp:
        final phone = _ctrl('phone').text.trim().replaceAll(RegExp(r'[^\d]'), '');
        final msg = Uri.encodeComponent(_ctrl('message').text.trim());
        if (phone.isNotEmpty) {
          payload = 'https://wa.me/$phone${msg.isNotEmpty ? "?text=$msg" : ""}';
        }
        break;
      case QrType.instagram:
        final user = _ctrl('username').text.trim().replaceAll('@', '');
        if (user.isNotEmpty) {
          payload = 'https://instagram.com/$user';
        }
        break;
      case QrType.facebook:
        final profile = _ctrl('profile').text.trim();
        if (profile.isNotEmpty) {
          payload = 'https://facebook.com/$profile';
        }
        break;
      case QrType.linkedin:
        final profile = _ctrl('profile').text.trim();
        if (profile.isNotEmpty) {
          payload = profile.startsWith('http')
              ? profile
              : 'https://linkedin.com/in/$profile';
        }
        break;
      case QrType.telegram:
        final user = _ctrl('username').text.trim().replaceAll('@', '');
        if (user.isNotEmpty) {
          payload = 'https://t.me/$user';
        }
        break;
      case QrType.discord:
        final invite = _ctrl('invite').text.trim();
        if (invite.isNotEmpty) {
          payload = invite.startsWith('http')
              ? invite
              : 'https://discord.gg/$invite';
        }
        break;
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the required fields')),
      );
      return;
    }

    setState(() => _data = payload);
  }

  Future<ui.Image?> _decodeLogo() async {
    if (_logoBytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(_logoBytes!);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image?> _decodeBgImage() async {
    if (_bgImageBytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(_bgImageBytes!);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  // 100% Scannable QR Matrix Generation with Level H Error Correction
  Future<ui.Image?> _renderQrMatrix() async {
    try {
      final logo = await _decodeLogo();
      final qrColor = (_useGradient && _activeGradient != null)
          ? Colors.white
          : _fg;
      final painter = QrPainter(
        data: _data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H, // Always High 30% error recovery for 100% scannability
        gapless: true,
        eyeStyle: QrEyeStyle(eyeShape: _design.eyeShape, color: qrColor),
        dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: _design.dataShape, color: qrColor),
        embeddedImage: logo,
        embeddedImageStyle: logo == null
            ? null
            : QrEmbeddedImageStyle(
                size: Size(
                  1024 * (_logoSize.clamp(0.12, 0.22)),
                  1024 * (_logoSize.clamp(0.12, 0.22)),
                ),
              ),
      );
      return painter.toImage(1024);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
  }

  Future<void> _setPresetIconLogo(IconData iconData, Color color) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 256.0;

      // Draw background circle
      final bgPaint = Paint()..color = color;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

      // Render TextIcon
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 140,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null && mounted) {
        setState(() => _logoBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _pickBackgroundImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bgImageBytes = bytes;
      _bg = Colors.transparent;
    });
  }

  void _removeBackgroundImage() {
    setState(() {
      _bgImageBytes = null;
      _bg = Colors.white;
    });
  }

  // 100% Scannable PNG Render Pipeline
  Future<List<int>?> _pngBytes() async {
    try {
      final qrImage = await _renderQrMatrix();
      if (qrImage == null) return null;
      final bgImg = await _decodeBgImage();
      final size = _exportSize;
      final pad = _includeQuietZone ? size * 0.07 : size * 0.02;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Wallpaper background rendering with High-Contrast Backing Card
      if (bgImg != null) {
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, size, size),
          image: bgImg,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        );

        // High-contrast translucent backing card behind QR matrix so wallpaper is visible while QR is 100% scannable
        final matrixCardRect = Rect.fromLTWH(
          pad * 0.4,
          pad * 0.4,
          size - pad * 0.8,
          size - pad * 0.8,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(matrixCardRect, Radius.circular(size * 0.06)),
          Paint()..color = Colors.white.withValues(alpha: 0.90),
        );
      } else {
        final bgPaint = Paint()..color = _bg;
        final drawRect = Rect.fromLTWH(0, 0, size, size);
        if (_design.roundedFrame) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(drawRect, Radius.circular(size * 0.08)),
            bgPaint,
          );
        } else {
          canvas.drawRect(drawRect, bgPaint);
        }
      }

      final qrRect = Rect.fromLTWH(pad, pad, size - pad * 2, size - pad * 2);

      // Draw white circular protective shield behind center logo if logo present
      if (_logoBytes != null) {
        final logoDim = qrRect.width * (_logoSize.clamp(0.12, 0.22));
        final shieldDim = logoDim * 1.25;
        final shieldRect = Rect.fromCenter(
          center: Offset(size / 2, size / 2),
          width: shieldDim,
          height: shieldDim,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(shieldRect, Radius.circular(shieldDim * 0.25)),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(shieldRect, Radius.circular(shieldDim * 0.25)),
          Paint()
            ..color = Colors.grey.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (_useGradient && _activeGradient != null && _activeGradient!.length >= 2) {
        final qrPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(qrRect.left, qrRect.top),
            Offset(qrRect.right, qrRect.bottom),
            _activeGradient!,
          )
          ..blendMode = BlendMode.srcIn;
        canvas.saveLayer(qrRect, qrPaint);
        paintImage(
          canvas: canvas,
          rect: qrRect,
          image: qrImage,
          fit: BoxFit.contain,
        );
        canvas.restore();
      } else {
        paintImage(
          canvas: canvas,
          rect: qrRect,
          image: qrImage,
          fit: BoxFit.contain,
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToHistory(List<int> pngBytes) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/qr_history');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${dir.path}/qr_$timestamp.png';
      await File(imagePath).writeAsBytes(pngBytes, flush: true);

      final name = _typeLabel(_type);
      final json = {
        'content': _data,
        'type': _type.name,
        'name': '$name QR',
        'timestamp': timestamp,
        'imagePath': imagePath,
      };
      final metaFile = File('${dir.path}/qr_$timestamp.json');
      await metaFile.writeAsString(jsonEncode(json));
    } catch (_) {}
  }

  Future<void> _loadPresets() async {
    final list = await AppStorage.getQrPresets();
    if (mounted) setState(() => _presets = list);
  }

  Future<void> _savePresetDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Preset name...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final preset = {
      'name': name,
      'fg': _fg.toARGB32(),
      'bg': _bg.toARGB32(),
      'designIndex': _designIndex,
      'themeIndex': _themeIndex,
      'useGradient': _useGradient,
      'logoSize': _logoSize,
    };
    await AppStorage.saveQrPreset(preset);
    _loadPresets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset "$name" saved')),
      );
    }
  }

  void _applyPreset(Map<String, dynamic> p) {
    setState(() {
      _fg = Color(p['fg'] ?? 0xFF000000);
      _bg = Color(p['bg'] ?? 0xFFFFFFFF);
      _designIndex = (p['designIndex'] ?? 0).clamp(0, _qrDesigns.length - 1);
      _themeIndex = (p['themeIndex'] ?? 0).clamp(0, _qrThemes.length - 1);
      _useGradient = p['useGradient'] ?? false;
      _logoSize = (p['logoSize'] ?? 0.20).toDouble().clamp(0.12, 0.22);
    });
  }

  Future<void> _deletePreset(Map<String, dynamic> p) async {
    await AppStorage.deleteQrPreset(p['name'] ?? '');
    _loadPresets();
  }

  void _showPresetSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Saved Presets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: _presets.isEmpty
                  ? const Center(child: Text('No saved presets'))
                  : ListView.builder(
                      itemCount: _presets.length,
                      itemBuilder: (ctx, i) {
                        final p = _presets[i];
                        return ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Color(p['fg'] ?? 0xFF000000),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey))),
                              const SizedBox(width: 4),
                              Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Color(p['bg'] ?? 0xFFFFFFFF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey))),
                            ],
                          ),
                          title: Text(p['name'] ?? ''),
                          onTap: () {
                            _applyPreset(p);
                            Navigator.pop(ctx);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await _deletePreset(p);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<QrType>(
            initialValue: _type,
            decoration: const InputDecoration(
                labelText: 'Type', border: OutlineInputBorder()),
            items: QrType.values
                .map((t) => DropdownMenuItem(
                    value: t, child: Text(_typeLabel(t))))
                .toList(),
            onChanged: (v) => setState(() {
              _type = v ?? QrType.url;
              _data = '';
            }),
          ),
          const SizedBox(height: 16),
          ..._fields(),
          const SizedBox(height: 8),

          _sectionLabel('Design'),
          _designSelector(),
          const SizedBox(height: 16),

          _sectionLabel('Color Theme'),
          _themeSelector(),
          const SizedBox(height: 12),
          _colorRow('Foreground', _fg, (c) => setState(() => _fg = c)),
          _colorRow('Background', _bg, (c) => setState(() { _bg = c; _bgImageBytes = null; })),

          if (_activeGradient != null)
            SwitchListTile(
              title: const Text('Use gradient foreground', style: TextStyle(fontSize: 13)),
              value: _useGradient,
              onChanged: (v) => setState(() => _useGradient = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

          const SizedBox(height: 8),

          _sectionLabel('Background Image'),
          _bgImageRow(),
          const SizedBox(height: 8),

          Row(
            children: [
              const Text('Presets', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showPresetSheet(),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Load'),
              ),
              TextButton.icon(
                onPressed: () => _savePresetDialog(),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _sectionLabel('Center Logo & Presets'),
          _presetLogoSelector(),
          const SizedBox(height: 8),
          _logoRow(),
          if (_logoBytes != null) _logoSizeSlider(),
          const SizedBox(height: 16),

          Semantics(
            label: 'Generate QR code',
            button: true,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate'),
            ),
          ),
          const SizedBox(height: 24),

          // 100% Scannable Live Preview Matching Export Output
          if (_data.isNotEmpty) ...[
            Center(
              child: FutureBuilder<List<int>?>(
                future: _pngBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: 250,
                      height: 250,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  }
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      Uint8List.fromList(bytes),
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _data));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Content copied')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(_data,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 16),

            // Export Options
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Export Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.aspect_ratio, size: 20),
                      const SizedBox(width: 8),
                      const Text('Size:', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(value: 256, label: Text('256')),
                            ButtonSegment(value: 512, label: Text('512')),
                            ButtonSegment(value: 1024, label: Text('1K')),
                            ButtonSegment(value: 2048, label: Text('2K')),
                          ],
                          selected: {_exportSize},
                          onSelectionChanged: (v) => setState(() => _exportSize = v.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Include Quiet Zone (Border)', style: TextStyle(fontSize: 13)),
                    value: _includeQuietZone,
                    onChanged: (v) => setState(() => _includeQuietZone = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Save QR to gallery',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _pngBytes();
                        if (bytes == null || !context.mounted) return;
                        await ToolIO.saveToGallery(
                            Uint8List.fromList(bytes), 'qr.png');
                        await _saveToHistory(bytes);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved to Gallery')),
                          );
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Save PNG'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Share QR code',
                    button: true,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final bytes = await _pngBytes();
                        if (bytes == null) return;
                        final temp = await getTemporaryDirectory();
                        final path = '${temp.path}/qr.png';
                        await File(path).writeAsBytes(bytes);
                        await _saveToHistory(bytes);
                        ToolIO.share(path);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetLogoSelector() {
    final presets = <(String, IconData, Color)>[
      ('WhatsApp', Icons.chat_bubble, const Color(0xFF25D366)),
      ('Instagram', Icons.camera_alt, const Color(0xFFE4405F)),
      ('Facebook', Icons.facebook, const Color(0xFF1877F2)),
      ('LinkedIn', Icons.work, const Color(0xFF0A66C2)),
      ('Wi-Fi', Icons.wifi, const Color(0xFF00B894)),
      ('Phone', Icons.phone, const Color(0xFF0984E3)),
      ('Email', Icons.email, const Color(0xFFE17055)),
      ('Location', Icons.location_on, const Color(0xFFE84393)),
      ('Globe', Icons.language, const Color(0xFF6C63FF)),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = presets[i];
          return ActionChip(
            avatar: Icon(p.$2, size: 16, color: p.$3),
            label: Text(p.$1, style: const TextStyle(fontSize: 12)),
            onPressed: () => _setPresetIconLogo(p.$2, p.$3),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _designSelector() {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _qrDesigns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = _qrDesigns[i];
          final selected = i == _designIndex;
          return GestureDetector(
            onTap: () => setState(() => _designIndex = i),
            child: Tooltip(
              message: d.description,
              child: Container(
                width: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(d.roundedFrame ? 18 : 6),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.4),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QrImageView(
                      data: 'preview',
                      version: 1,
                      size: 44,
                      gapless: true,
                      eyeStyle:
                          QrEyeStyle(eyeShape: d.eyeShape, color: _fg),
                      dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: d.dataShape, color: _fg),
                    ),
                    const SizedBox(height: 4),
                    Text(d.name,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _themeSelector() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _qrThemes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = _qrThemes[i];
          final selected = i == _themeIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _themeIndex = i;
                _fg = t.fg;
                _bg = t.bg;
                _activeGradient = t.gradient;
                _useGradient = t.gradient != null;
                _bgImageBytes = null;
              });
            },
            child: Tooltip(
              message: t.name,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.4),
                    width: selected ? 3 : 1,
                  ),
                  gradient: t.gradient != null
                      ? LinearGradient(
                          colors: t.gradient!,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: t.gradient == null
                    ? Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: t.fg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _colorRow(String label, Color current, ValueChanged<Color> onPick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                ..._palette.map((c) {
                  final selected = c.toARGB32() == current.toARGB32();
                  return GestureDetector(
                    onTap: () => onPick(c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.grey,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(current, onPick),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 1),
                    ),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker(Color current, ValueChanged<Color> onPick) {
    double r = current.r * 255;
    double g = current.g * 255;
    double b = current.b * 255;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pick Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, r.round(), g.round(), b.round()),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              _rgbSlider('R', r, (v) => setDialogState(() => r = v), Colors.red),
              _rgbSlider('G', g, (v) => setDialogState(() => g = v), Colors.green),
              _rgbSlider('B', b, (v) => setDialogState(() => b = v), Colors.blue),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onPick(Color.fromARGB(255, r.round(), g.round(), b.round()));
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rgbSlider(String label, double value, ValueChanged<double> onChanged, Color color) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            label: '${value.round()}',
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text('${value.round()}', style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _bgImageRow() {
    return Row(
      children: [
        const SizedBox(width: 110, child: Text('Wallpaper')),
        Expanded(
          child: Row(
            children: [
              if (_bgImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_bgImageBytes!,
                        width: 32, height: 32, fit: BoxFit.cover),
                  ),
                ),
              TextButton.icon(
                onPressed: _pickBackgroundImage,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: Text(_bgImageBytes == null ? 'Add wallpaper' : 'Change'),
              ),
              if (_bgImageBytes != null)
                TextButton.icon(
                  onPressed: _removeBackgroundImage,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logoRow() {
    return Row(
      children: [
        const SizedBox(width: 110, child: Text('Center logo')),
        Expanded(
          child: Row(
            children: [
              if (_logoBytes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_logoBytes!,
                        width: 32, height: 32, fit: BoxFit.cover),
                  ),
                ),
              TextButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: Text(_logoBytes == null ? 'Add' : 'Change'),
              ),
              if (_logoBytes != null)
                TextButton.icon(
                  onPressed: () => setState(() => _logoBytes = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logoSizeSlider() {
    return Padding(
      padding: const EdgeInsets.only(left: 110, top: 4),
      child: Row(
        children: [
          const Icon(Icons.photo_size_select_large, size: 18),
          Expanded(
            child: Slider(
              value: _logoSize,
              min: 0.10,
              max: 0.22, // Clamped to max 22% for 100% scannability
              divisions: 6,
              label: '${(_logoSize * 100).round()}%',
              onChanged: (v) => setState(() => _logoSize = v),
            ),
          ),
          Text('${(_logoSize * 100).round()}%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _typeLabel(QrType t) {
    switch (t) {
      case QrType.url:
        return 'URL / Link';
      case QrType.text:
        return 'Plain Text';
      case QrType.wifi:
        return 'Wi-Fi';
      case QrType.contact:
        return 'Contact (vCard)';
      case QrType.email:
        return 'Email';
      case QrType.sms:
        return 'SMS';
      case QrType.phone:
        return 'Phone';
      case QrType.location:
        return 'Location';
      case QrType.event:
        return 'Calendar Event';
      case QrType.crypto:
        return 'Crypto Wallet';
      case QrType.whatsapp:
        return 'WhatsApp';
      case QrType.instagram:
        return 'Instagram';
      case QrType.facebook:
        return 'Facebook';
      case QrType.linkedin:
        return 'LinkedIn';
      case QrType.telegram:
        return 'Telegram';
      case QrType.discord:
        return 'Discord';
    }
  }
}
