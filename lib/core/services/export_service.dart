import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

import 'package:xscan/core/services/app_storage.dart';

/// Builds exportable documents (DOCX/CSV/JSON/TXT) from text or structured data.
class ExportService {
  /// Writes plain text and returns the file path.
  static Future<String> exportTxt(String name, String text) {
    return AppStorage.writeExport('$name.txt', utf8.encode(text));
  }

  /// Writes a minimal but valid .docx (OOXML) file from [text].
  static Future<String> exportDocx(String name, String text) async {
    final paragraphs = text.split('\n');
    final body = StringBuffer();
    for (final line in paragraphs) {
      final escaped = _xmlEscape(line);
      body.write(
        '<w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>',
      );
    }

    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${body.toString()}<w:sectPr/></w:body></w:document>';

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', document);

    final zipped = ZipEncoder().encode(archive);
    return AppStorage.writeExport('$name.docx', zipped);
  }

  /// Writes CSV from rows and returns the path.
  static Future<String> exportCsv(String name, List<List<dynamic>> rows) {
    final csv = const ListToCsvConverter().convert(rows);
    return AppStorage.writeExport('$name.csv', utf8.encode(csv));
  }

  /// Writes pretty JSON and returns the path.
  static Future<String> exportJson(String name, Object data) {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    return AppStorage.writeExport('$name.json', utf8.encode(json));
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
