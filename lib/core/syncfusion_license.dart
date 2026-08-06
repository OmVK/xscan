import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

/// Registers the Syncfusion license key.
///
/// IMPORTANT: XScan uses Syncfusion's commercial plugins
/// (`syncfusion_flutter_pdf` + `syncfusion_flutter_pdfviewer`). In production
/// you MUST paste a license key from
/// https://www.syncfusion.com/account/manual-trials into
/// [SyncSettings.licenseKey], otherwise the plugins keep rendering the "TRIAL"
/// watermark and publishing to the Play Store violates the license agreement.
///
/// The license is stored by Syncfusion's shared core plugin, so registering it
/// once through the PDF package covers the PDF viewer as well.
class SyncSettings {
  /// Paste your Syncfusion license key here.
  static const String licenseKey = '';

  /// Registers the license key for the Syncfusion plugins used by XScan.
  static void register() {
    if (licenseKey.isEmpty) {
      // No key configured yet — the app still runs with Syncfusion's trial
      // behaviour. Set [licenseKey] before shipping a production build.
      return;
    }
    sfpdf.SyncfusionLicense.registerLicense(licenseKey);
  }
}