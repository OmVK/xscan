// This file previously contained a custom RC4-128 encryption implementation
// which is cryptographically broken (RFC 7465). All PDF encryption now uses
// Syncfusion's AES-256 implementation via PdfToolsService.setPassword().
//
// This file is kept as a deprecated stub to avoid breaking imports during
// migration. It will be removed in the next major version.

@Deprecated(
    'RC4 is broken. Use PdfToolsService.setPassword() with AES-256 instead.')
class PdfStandardEncryption {
  @Deprecated('RC4 is broken. Use AES-256 encryption via Syncfusion.')
  PdfStandardEncryption(
    dynamic pdfDocument, {
    required String userPassword,
    String? ownerPassword,
  }) {
    throw UnsupportedError(
      'RC4 encryption has been removed for security reasons. '
      'Use PdfToolsService.setPassword() which uses AES-256 encryption.',
    );
  }
}
