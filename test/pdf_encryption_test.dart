import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
// ignore: deprecated_member_use_from_same_package
import 'package:xscan/core/services/pdf_encryption.dart' as pdf_encryption;

void main() {
  test('AES-256 encrypted PDF contains Standard security handler', () async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(child: pw.Text('Confidential')),
      ),
    );

    final Uint8List rawBytes = await pdf.save();

    final sfDoc = sf.PdfDocument(inputBytes: rawBytes);
    sfDoc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;
    sfDoc.security.userPassword = 'secret123';
    sfDoc.security.ownerPassword = 'secret123';
    final Uint8List encryptedBytes = Uint8List.fromList(await sfDoc.save());
    sfDoc.dispose();

    final content = String.fromCharCodes(encryptedBytes);

    expect(content.contains('/Encrypt'), isTrue);
    expect(
      content.contains('/Filter /Standard') ||
          content.contains('/Filter/Standard'),
      isTrue,
    );
    expect(content.contains('/V 5'), isTrue);
    expect(content.contains('/R 6'), isTrue);
    expect(content.contains('Confidential'), isFalse);
  });

  test('deprecated PdfStandardEncryption throws UnsupportedError', () {
    // ignore: deprecated_member_use_from_same_package
    expect(
      () => pdf_encryption.PdfStandardEncryption(
        null,
        userPassword: 'test',
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
