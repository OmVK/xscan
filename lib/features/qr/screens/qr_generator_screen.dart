import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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

/// A visual style preset controlling module & eye shapes.
class QrDesign {
  const QrDesign({
    required this.name,
    required this.eyeShape,
    required this.dataShape,
    this.roundedFrame = false,
  });

  final String name;
  final QrEyeShape eyeShape;
  final QrDataModuleShape dataShape;
  final bool roundedFrame;
}

const _qrDesigns = <QrDesign>[
  QrDesign(
    name: 'Classic',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.square,
  ),
  QrDesign(
    name: 'Rounded',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.circle,
    roundedFrame: true,
  ),
  QrDesign(
    name: 'Dots',
    eyeShape: QrEyeShape.square,
    dataShape: QrDataModuleShape.circle,
  ),
  QrDesign(
    name: 'Smooth',
    eyeShape: QrEyeShape.circle,
    dataShape: QrDataModuleShape.square,
    roundedFrame: true,
  ),
];

/// Curated foreground/background color themes.
class QrColorTheme {
  const QrColorTheme(this.name, this.fg, this.bg);
  final String name;
  final Color fg;
  final Color bg;
}

const _qrThemes = <QrColorTheme>[
  QrColorTheme('Ink', Colors.black, Colors.white),
  QrColorTheme('Violet', Color(0xFF6C63FF), Color(0xFFF3F1FF)),
  QrColorTheme('Emerald', Color(0xFF00B894), Color(0xFFEFFFF9)),
  QrColorTheme('Rose', Color(0xFFE84393), Color(0xFFFFF0F7)),
  QrColorTheme('Ocean', Color(0xFF0984E3), Color(0xFFEFF8FF)),
  QrColorTheme('Sunset', Color(0xFFE17055), Color(0xFFFFF3EF)),
  QrColorTheme('Midnight', Color(0xFF00E5FF), Color(0xFF0F0F13)),
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
  Uint8List? _logoBytes;

  QrDesign get _design => _qrDesigns[_designIndex];

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
          _dropdownEnc(),
        ];
      case QrType.contact:
        return [
          _field('name', 'Full name'),
          _field('phone', 'Phone'),
          _field('email', 'Email'),
          _field('org', 'Organization'),
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
          _field('location', 'Location'),
          _field('start', 'Start (YYYYMMDDTHHMMSS)'),
          _field('end', 'End (YYYYMMDDTHHMMSS)'),
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

  /// Escapes special characters for WiFi QR format (RFC 7987).
  /// Escapes: \\, ;, , , : , "
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
        return 'WIFI:T:$_enc;S:${_wifiEscape(g('ssid'))};P:${_wifiEscape(g('password'))};;';
      case QrType.contact:
        return 'BEGIN:VCARD\nVERSION:3.0\nFN:${g('name')}\n'
            'TEL:${g('phone')}\nEMAIL:${g('email')}\nORG:${g('org')}\nEND:VCARD';
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
        return 'BEGIN:VEVENT\nSUMMARY:${g('title')}\nLOCATION:${g('location')}\n'
            'DTSTART:${g('start')}\nDTEND:${g('end')}\nEND:VEVENT';
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

  Future<ui.Image?> _decodeLogo() async {
    if (_logoBytes == null) return null;
    final codec = await ui.instantiateImageCodec(_logoBytes!);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _renderImage() async {
    final logo = await _decodeLogo();
    final painter = QrPainter(
      data: _data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: QrEyeStyle(eyeShape: _design.eyeShape, color: _fg),
      dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: _design.dataShape, color: _fg),
      embeddedImage: logo,
      embeddedImageStyle: logo == null
          ? null
          : const QrEmbeddedImageStyle(size: Size(220, 220)),
    );
    return painter.toImage(1024);
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
  }

  Future<List<int>?> _pngBytes() async {
    final qr = await _renderImage();
    const size = 1152.0;
    const pad = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bgPaint = Paint()..color = _bg;
    final rect = const Rect.fromLTWH(0, 0, size, size);
    if (_design.roundedFrame) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(96)),
        bgPaint,
      );
    } else {
      canvas.drawRect(rect, bgPaint);
    }
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(pad, pad, size - pad * 2, size - pad * 2),
      image: qr,
      fit: BoxFit.contain,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _save() async {
    final bytes = await _pngBytes();
    if (bytes == null || !mounted) return;
    final path = await AppStorage.writeExport('qr_code.png', bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved: $path')));
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
          const SizedBox(height: 12),
          _sectionLabel('Color theme'),
          _themeSelector(),
          const SizedBox(height: 8),
          _colorRow('Foreground', _fg, (c) => setState(() => _fg = c)),
          _colorRow('Background', _bg, (c) => setState(() => _bg = c)),
          const SizedBox(height: 8),
          _logoRow(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.qr_code),
            label: const Text('Generate'),
          ),
          const SizedBox(height: 24),
          if (_data.isNotEmpty) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(
                      _design.roundedFrame ? 24 : 4),
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
                      : const QrEmbeddedImageStyle(size: Size(52, 52)),
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
        ],
      ),
    );
  }

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
          );
        },
      ),
    );
  }

  Widget _themeSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _qrThemes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = _qrThemes[i];
          final selected = t.fg.toARGB32() == _fg.toARGB32() &&
              t.bg.toARGB32() == _bg.toARGB32();
          return GestureDetector(
            onTap: () => setState(() {
              _fg = t.fg;
              _bg = t.bg;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withValues(alpha: 0.4),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration:
                        BoxDecoration(color: t.fg, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(t.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: t.fg.computeLuminance() > 0.5
                              ? Colors.black
                              : t.fg)),
                ],
              ),
            ),
          );
        },
      ),
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

  Widget _colorRow(String label, Color current, ValueChanged<Color> onPick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: _palette.map((c) {
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
              }).toList(),
            ),
          ),
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
