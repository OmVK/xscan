import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xscan/core/services/pdf_encryption.dart';

void main() {
  test('encrypted PDF contains a Standard security handler', () async {
    final pdf = pw.Document();
    pdf.document.encryption = PdfStandardEncryption(
      pdf.document,
      userPassword: 'secret123',
    );
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(child: pw.Text('Confidential')),
      ),
    );

    final Uint8List bytes = await pdf.save();
    final content = String.fromCharCodes(bytes);

    expect(content.contains('/Encrypt'), isTrue);
    expect(content.contains('/Filter /Standard') || content.contains('/Filter/Standard'),
        isTrue);
    expect(content.contains('/V 2'), isTrue);
    expect(content.contains('/R 3'), isTrue);
    // The plaintext must no longer be visible in the encrypted stream.
    expect(content.contains('Confidential'), isFalse);
  });
}
