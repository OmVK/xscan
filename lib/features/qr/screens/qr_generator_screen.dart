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
  // Classic
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
  // Rounded family
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
  // Dots family
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
  // Unique shapes
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
  // Classic
  QrColorTheme('Ink', Colors.black, Colors.white),
  QrColorTheme('Paper', Color(0xFF2C2C2C), Color(0xFFFAFAFA)),
  // Vibrant
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
  // Dark themes
  QrColorTheme('Midnight', Color(0xFF00E5FF), Color(0xFF0F0F13)),
  QrColorTheme('Obsidian', Color(0xFFBB86FC), Color(0xFF121212)),
  QrColorTheme('Carbon', Color(0xFF03DAC6), Color(0xFF1B1B1B)),
  QrColorTheme('Onyx', Color(0xFFCF6679), Color(0xFF121212)),
  // Premium
  QrColorTheme('Gold', Color(0xFFFFD700), Color(0xFF1A1A2E)),
  QrColorTheme('Royal', Color(0xFF9C27B0), Color(0xFFF3E5F5)),
  QrColorTheme('Forest', Color(0xFF2E7D32), Color(0xFFE8F5E9)),
  QrColorTheme('Crimson', Color(0xFFC62828), Color(0xFFFFEBEE)),
  // Gradients
  QrColorTheme('Aurora', Color(0xFF7C4DFF), Color(0xFF18FFFF),
      gradient: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
  QrColorTheme('Sunrise', Color(0xFFFF6F00), Color(0xFFFFF3E0),
      gradient: [Color(0xFFFF6F00), Color(0xFFFF1744)]),
  QrColorTheme('Ocean Deep', Color(0xFF00BFA5), Color(0xFFE0F7FA),
      gradient: [Color(0xFF00BFA5), Color(0xFF2979FF)]),
];

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

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
  bool _hidden = false;
  List<Map<String, dynamic>> _presets = [];
  double _exportSize = 1024;
  bool _includeQuietZone = true;
  double _logoSize = 0.22;
  bool _useGradient = false;
  List<Color>? _activeGradient;

  QrDesign get _design => _qrDesigns[_designIndex];

  @override
  void initState() {
    super.initState();
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

  // ──────────────────────── Fields ────────────────────────

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
            title: const Text('Hidden network', style: TextStyle(fontSize: 14)),
            leading: Checkbox(
              value: _hidden,
              onChanged: (v) => setState(() => _hidden = v ?? false),
            ),
          ),
          _dropdownEnc(),
        ];
      case QrType.contact:
        return [
          _field('name', 'Full name'),
          _field('phone', 'Phone'),
          _field('email', 'Email'),
          _field('org', 'Organization'),
          _field('website', 'Website', hint: 'https://example.com'),
        ];
      case QrType.email:
        return [
          _field('to', 'Email address'),
          _field('subject', 'Subject'),
          _field('body', 'Body', lines: 3),
        ];
      case QrType.sms:
        return [_field('phone', 'Phone'), _field('message', 'Message', lines: 2)];
      case QrType.phone:
        return [_field('phone', 'Phone number')];
      case QrType.location:
        return [_field('lat', 'Latitude'), _field('lng', 'Longitude')];
      case QrType.event:
        return [
          _field('title', 'Event title'),
          _field('description', 'Description', lines: 2),
          _field('location', 'Location'),
          _dateTimeField('start', 'Start'),
          _dateTimeField('end', 'End'),
        ];
      case QrType.crypto:
        return [
          _dropdownCoin(),
          _field('address', 'Wallet address'),
          _field('amount', 'Amount (optional)'),
        ];
      case QrType.whatsapp:
        return [_field('phone', 'Phone (with country code)')];
      case QrType.instagram:
        return [_field('user', 'Username')];
      case QrType.facebook:
        return [_field('user', 'Username or page')];
      case QrType.linkedin:
        return [_field('user', 'Profile (in/username)')];
      case QrType.telegram:
        return [_field('user', 'Username')];
      case QrType.discord:
        return [_field('invite', 'Invite code or URL')];
    }
  }

  String _coin = 'bitcoin';
  String _enc = 'WPA';

  Widget _dropdownCoin() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _coin,
          decoration: const InputDecoration(
              labelText: 'Coin', border: OutlineInputBorder()),
          items: const ['bitcoin', 'ethereum', 'litecoin']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _coin = v ?? 'bitcoin'),
        ),
      );

  Widget _dropdownEnc() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _enc,
          decoration: const InputDecoration(
              labelText: 'Encryption', border: OutlineInputBorder()),
          items: const ['WPA', 'WEP', 'nopass']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _enc = v ?? 'WPA'),
        ),
      );

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
      ),
    );
  }

  Widget _dateTimeField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _ctrl(key),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Tap to pick date & time',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () => _pickDateTime(key),
      ),
    );
  }

  Future<void> _pickDateTime(String key) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final formatted = '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}00';
    _ctrl(key).text = formatted;
  }

  String _wifiEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll(':', '\\:')
      .replaceAll('"', '\\"');

  String _build() {
    String g(String k) => _ctrl(k).text.trim();
    switch (_type) {
      case QrType.url:
        return g('url');
      case QrType.text:
        return g('text');
      case QrType.wifi:
        final hidden = _hidden ? 'H:true;' : '';
        return 'WIFI:T:$_enc;S:${_wifiEscape(g('ssid'))};P:${_wifiEscape(g('password'))};$hidden';
      case QrType.contact:
        final website = g('website').isNotEmpty ? '\nURL:${g('website')}' : '';
        return 'BEGIN:VCARD\nVERSION:3.0\nFN:${g('name')}\n'
            'TEL:${g('phone')}\nEMAIL:${g('email')}\nORG:${g('org')}$website\nEND:VCARD';
      case QrType.email:
        return 'mailto:${g('to')}?subject=${Uri.encodeComponent(g('subject'))}'
            '&body=${Uri.encodeComponent(g('body'))}';
      case QrType.sms:
        return 'SMSTO:${g('phone')}:${g('message')}';
      case QrType.phone:
        return 'tel:${g('phone')}';
      case QrType.location:
        return 'geo:${g('lat')},${g('lng')}';
      case QrType.event:
        final desc = g('description').isNotEmpty ? '\nDESCRIPTION:${g('description')}' : '';
        return 'BEGIN:VEVENT\nSUMMARY:${g('title')}\nLOCATION:${g('location')}\n'
            'DTSTART:${g('start')}\nDTEND:${g('end')}$desc\nEND:VEVENT';
      case QrType.crypto:
        final amt = g('amount').isEmpty ? '' : '?amount=${g('amount')}';
        return '$_coin:${g('address')}$amt';
      case QrType.whatsapp:
        return 'https://wa.me/${g('phone').replaceAll(RegExp(r'[^0-9]'), '')}';
      case QrType.instagram:
        return 'https://instagram.com/${g('user')}';
      case QrType.facebook:
        return 'https://facebook.com/${g('user')}';
      case QrType.linkedin:
        final u = g('user');
        return u.startsWith('in/') || u.startsWith('company/')
            ? 'https://linkedin.com/$u'
            : 'https://linkedin.com/in/$u';
      case QrType.telegram:
        return 'https://t.me/${g('user')}';
      case QrType.discord:
        final v = g('invite');
        return v.startsWith('http') ? v : 'https://discord.gg/$v';
    }
  }

  // ──────────────────────── Image helpers ────────────────────────

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

  Future<ui.Image?> _renderQrMatrix() async {
    try {
      final logo = await _decodeLogo();
      final qrColor = (_useGradient && _activeGradient != null)
          ? Colors.white
          : _fg;
      final painter = QrPainter(
        data: _data,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: QrEyeStyle(eyeShape: _design.eyeShape, color: qrColor),
        dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: _design.dataShape, color: qrColor),
        embeddedImage: logo,
        embeddedImageStyle: logo == null
            ? null
            : QrEmbeddedImageStyle(
                size: Size(
                  220 * _logoSize / 0.22,
                  220 * _logoSize / 0.22,
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

  Future<List<int>?> _pngBytes() async {
    try {
      final qrImage = await _renderQrMatrix();
      if (qrImage == null) return null;
      final bgImg = await _decodeBgImage();
      final size = _exportSize;
      final pad = _includeQuietZone ? size * 0.06 : 0.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      if (bgImg != null) {
        paintImage(
          canvas: canvas,
          rect: const Rect.fromLTWH(0, 0, 0, 0).inflate(size / 2),
          image: bgImg,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size, size),
          Paint()..color = Colors.white.withValues(alpha: 0.15),
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

  Future<void> _save() async {
    final bytes = await _pngBytes();
    if (bytes == null || !mounted) return;
    final sizeLabel = _exportSize.toInt();
    final path = await AppStorage.writeExport('qr_${sizeLabel}px.png', bytes);
    if (!mounted) return;
    final msg = 'Saved: $path';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _share() async {
    final bytes = await _pngBytes();
    if (bytes == null || !mounted) return;
    final path = await AppStorage.writeExport('qr_code.png', bytes);
    await ToolIO.share(path, text: 'QR Code');
  }

  void _generate() {
    HapticFeedback.mediumImpact();
    setState(() => _data = _build());
  }

  // ──────────────────────── Presets ────────────────────────

  Future<void> _loadPresets() async {
    final dir = await getApplicationDocumentsDirectory();
    final presetsDir = Directory('${dir.path}/qr_presets');
    if (!await presetsDir.exists()) return;
    final files = await presetsDir.list().where((f) => f.path.endsWith('.json')).toList();
    _presets = [];
    for (final f in files) {
      final json = jsonDecode(await (f as File).readAsString());
      _presets.add(json);
    }
    _presets.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
  }

  Future<void> _savePreset(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final presetsDir = Directory('${dir.path}/qr_presets');
    await presetsDir.create(recursive: true);
    final preset = {
      'name': name,
      'designIndex': _designIndex,
      'themeIndex': _themeIndex,
      'fg': _fg.toARGB32(),
      'bg': _bg.toARGB32(),
      'logoSize': _logoSize,
      'date': DateTime.now().toIso8601String(),
    };
    final file = File('${presetsDir.path}/${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.json');
    await file.writeAsString(jsonEncode(preset));
    await _loadPresets();
  }

  Future<void> _deletePreset(Map<String, dynamic> preset) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = preset['name'] as String;
    final file = File('${dir.path}/qr_presets/${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.json');
    if (await file.exists()) await file.delete();
    await _loadPresets();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _designIndex = preset['designIndex'] ?? 0;
      _themeIndex = preset['themeIndex'] ?? 0;
      _fg = Color(preset['fg'] ?? 0xFF000000);
      _bg = Color(preset['bg'] ?? 0xFFFFFFFF);
      _logoSize = (preset['logoSize'] as num?)?.toDouble() ?? 0.22;
    });
  }

  Future<void> _savePresetDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Style Preset'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Preset name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _savePreset(name);
    if (!mounted) return;
    final msg = 'Preset "$name" saved';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showPresetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
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
                      controller: scrollCtrl,
                      itemCount: _presets.length,
                      itemBuilder: (ctx, i) {
                        final p = _presets[i];
                        return ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 16, height: 16, decoration: BoxDecoration(color: Color(p['fg'] ?? 0xFF000000), shape: BoxShape.circle, border: Border.all(color: Colors.grey))),
                              const SizedBox(width: 4),
                              Container(width: 16, height: 16, decoration: BoxDecoration(color: Color(p['bg'] ?? 0xFFFFFFFF), shape: BoxShape.circle, border: Border.all(color: Colors.grey))),
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

  // ──────────────────────── Build ────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type selector
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

          // ── Design ──
          _sectionLabel('Design'),
          _designSelector(),
          const SizedBox(height: 16),

          // ── Color Theme ──
          _sectionLabel('Color Theme'),
          _themeSelector(),
          const SizedBox(height: 12),
          _colorRow('Foreground', _fg, (c) => setState(() => _fg = c)),
          _colorRow('Background', _bg, (c) => setState(() { _bg = c; _bgImageBytes = null; })),

          // ── Gradient toggle ──
          if (_activeGradient != null)
            SwitchListTile(
              title: const Text('Use gradient foreground', style: TextStyle(fontSize: 13)),
              value: _useGradient,
              onChanged: (v) => setState(() => _useGradient = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

          const SizedBox(height: 8),

          // ── Background Image ──
          _sectionLabel('Background Image'),
          _bgImageRow(),
          const SizedBox(height: 8),

          // ── Presets ──
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

          // ── Logo ──
          _logoRow(),
          if (_logoBytes != null) _logoSizeSlider(),
          const SizedBox(height: 16),

          // ── Generate ──
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

          // ── Preview ──
          if (_data.isNotEmpty) ...[
            Center(
              child: Semantics(
                label: 'QR code preview',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgImageBytes != null ? Colors.grey.withValues(alpha: 0.1) : _bg,
                    borderRadius: BorderRadius.circular(
                        _design.roundedFrame ? 24 : 4),
                    image: _bgImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_bgImageBytes!),
                            fit: BoxFit.cover,
                            opacity: 0.3,
                          )
                        : null,
                  ),
                  child: QrImageView(
                    data: _data,
                    version: QrVersions.auto,
                    size: 240,
                    gapless: true,
                    eyeStyle:
                        QrEyeStyle(eyeShape: _design.eyeShape, color: _fg),
                    dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: _design.dataShape, color: _fg),
                    embeddedImage: _logoBytes == null
                        ? null
                        : MemoryImage(_logoBytes!),
                    embeddedImageStyle: _logoBytes == null
                        ? null
                        : QrEmbeddedImageStyle(
                            size: Size(
                              52 * _logoSize / 0.22,
                              52 * _logoSize / 0.22,
                            ),
                          ),
                  ),
                ),
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

            // ── Export Options ──
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
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Quiet zone (margin)', style: TextStyle(fontSize: 13)),
                    value: _includeQuietZone,
                    onChanged: (v) => setState(() => _includeQuietZone = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Save / Share ──
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Save QR code',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.download),
                      label: const Text('Save'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Share QR code',
                    button: true,
                    child: FilledButton.icon(
                      onPressed: _share,
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

  // ──────────────────────── UI Widgets ────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _designSelector() {
    return SizedBox(
      height: 92,
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
                // Custom color picker button
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
              // Preview
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
              max: 0.35,
              divisions: 5,
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
