// ignore_for_file: implementation_imports
//
// Implements the PDF "Standard" security handler (RC4, revision 3, 128-bit)
// as described in the PDF 1.6 specification (Algorithms 2-5). The high-level
// `pdf` package only ships an abstract [PdfEncryption], so the concrete
// password-based handler is provided here.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/object_base.dart';
import 'package:pdf/src/pdf/format/string.dart';

/// Standard 32-byte password padding string from the PDF specification.
const List<int> _padding = <int>[
  0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, //
  0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
  0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
  0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
];

class PdfStandardEncryption extends PdfEncryption {
  PdfStandardEncryption(
    super.pdfDocument, {
    required String userPassword,
    String? ownerPassword,
  })  : _userPassword = userPassword,
        _ownerPassword = (ownerPassword == null || ownerPassword.isEmpty)
            ? userPassword
            : ownerPassword;

  final String _userPassword;
  final String _ownerPassword;

  static const int _keyLength = 16; // 128-bit
  static const int _revision = 3;
  static const int _version = 2;

  /// Permission flags. 0xFFFFFFFC (-4) grants every standard permission while
  /// still requiring the password to open the document.
  static const int _permissions = -4;

  Uint8List? _encryptionKey;
  Uint8List? _ownerEntry;
  Uint8List? _userEntry;

  Uint8List _bytesFromPassword(String password) {
    return Uint8List.fromList(
      password.codeUnits.map((c) => c & 0xff).toList(growable: false),
    );
  }

  Uint8List _padPassword(String password) {
    final bytes = _bytesFromPassword(password);
    final out = Uint8List(32);
    final n = bytes.length > 32 ? 32 : bytes.length;
    out.setRange(0, n, bytes);
    if (n < 32) out.setRange(n, 32, _padding);
    return out;
  }

  Uint8List _rc4(Uint8List key, Uint8List data) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xff;
      final t = s[i];
      s[i] = s[j];
      s[j] = t;
    }

    final out = Uint8List(data.length);
    var a = 0;
    var b = 0;
    for (var k = 0; k < data.length; k++) {
      a = (a + 1) & 0xff;
      b = (b + s[a]) & 0xff;
      final t = s[a];
      s[a] = s[b];
      s[b] = t;
      out[k] = data[k] ^ s[(s[a] + s[b]) & 0xff];
    }
    return out;
  }

  Uint8List _md5(List<int> input) => Uint8List.fromList(md5.convert(input).bytes);

  Uint8List _keyXor(Uint8List key, int value) {
    final out = Uint8List(key.length);
    for (var i = 0; i < key.length; i++) {
      out[i] = key[i] ^ value;
    }
    return out;
  }

  /// Algorithm 3: compute the /O (owner password) entry.
  Uint8List _computeOwnerEntry() {
    var digest = _md5(_padPassword(_ownerPassword));
    for (var i = 0; i < 50; i++) {
      digest = _md5(digest.sublist(0, _keyLength));
    }
    final rc4Key = digest.sublist(0, _keyLength);

    var data = _rc4(rc4Key, _padPassword(_userPassword));
    for (var i = 1; i <= 19; i++) {
      data = _rc4(_keyXor(rc4Key, i), data);
    }
    return data;
  }

  /// Algorithm 2: compute the encryption key.
  Uint8List _computeEncryptionKey(Uint8List ownerEntry, Uint8List documentId) {
    final builder = BytesBuilder();
    builder.add(_padPassword(_userPassword));
    builder.add(ownerEntry);
    final p = ByteData(4)..setInt32(0, _permissions, Endian.little);
    builder.add(p.buffer.asUint8List());
    builder.add(documentId);

    var digest = _md5(builder.toBytes());
    for (var i = 0; i < 50; i++) {
      digest = _md5(digest.sublist(0, _keyLength));
    }
    return digest.sublist(0, _keyLength);
  }

  /// Algorithm 5: compute the /U (user password) entry.
  Uint8List _computeUserEntry(Uint8List key, Uint8List documentId) {
    final builder = BytesBuilder();
    builder.add(_padding);
    builder.add(documentId);

    var data = _md5(builder.toBytes());
    data = _rc4(key, data);
    for (var i = 1; i <= 19; i++) {
      data = _rc4(_keyXor(key, i), data);
    }

    final out = Uint8List(32);
    out.setRange(0, 16, data);
    out.setRange(16, 32, _padding); // arbitrary padding
    return out;
  }

  void _ensureKeys() {
    if (_encryptionKey != null) return;
    final documentId = pdfDocument.documentID;
    _ownerEntry = _computeOwnerEntry();
    _encryptionKey = _computeEncryptionKey(_ownerEntry!, documentId);
    _userEntry = _computeUserEntry(_encryptionKey!, documentId);
  }

  @override
  void prepare() {
    super.prepare();
    _ensureKeys();
    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(_version);
    params['/R'] = const PdfNum(_revision);
    params['/Length'] = const PdfNum(_keyLength * 8);
    params['/P'] = const PdfNum(_permissions);
    params['/O'] = PdfString(_ownerEntry!, format: PdfStringFormat.binary, encrypted: false);
    params['/U'] = PdfString(_userEntry!, format: PdfStringFormat.binary, encrypted: false);
  }

  /// Algorithm 1: encrypt string/stream data of an individual object.
  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    _ensureKeys();
    final builder = BytesBuilder();
    builder.add(_encryptionKey!);
    builder.add(<int>[
      object.objser & 0xff,
      (object.objser >> 8) & 0xff,
      (object.objser >> 16) & 0xff,
      object.objgen & 0xff,
      (object.objgen >> 8) & 0xff,
    ]);

    final digest = _md5(builder.toBytes());
    final n = (_keyLength + 5) > 16 ? 16 : (_keyLength + 5);
    final objectKey = digest.sublist(0, n);
    return _rc4(objectKey, input);
  }
}
