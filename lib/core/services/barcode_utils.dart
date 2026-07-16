import 'package:mobile_scanner/mobile_scanner.dart';

/// Helpers for labeling and interpreting scanned barcodes.
class BarcodeUtils {
  static String formatLabel(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.all:
        return 'Barcode';
      default:
        return 'Barcode';
    }
  }

  /// Detects higher-level semantic types (VIN, ISBN) from the value/format.
  static String semanticType(Barcode barcode) {
    final value = barcode.rawValue ?? '';
    final base = formatLabel(barcode.format);
    if (barcode.format == BarcodeFormat.ean13 &&
        (value.startsWith('978') || value.startsWith('979'))) {
      return 'ISBN ($base)';
    }
    if (value.length == 17 &&
        RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(value.toUpperCase())) {
      return 'VIN ($base)';
    }
    return base;
  }

  /// Categorizes the QR/barcode content for quick actions.
  static BarcodeContentKind contentKind(String value) {
    final v = value.trim();
    final lower = v.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return BarcodeContentKind.url;
    }
    if (lower.startsWith('wifi:')) return BarcodeContentKind.wifi;
    if (lower.startsWith('mailto:') || lower.startsWith('matmsg:')) {
      return BarcodeContentKind.email;
    }
    if (lower.startsWith('tel:')) return BarcodeContentKind.phone;
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      return BarcodeContentKind.sms;
    }
    if (lower.startsWith('begin:vcard')) return BarcodeContentKind.contact;
    if (lower.startsWith('begin:vevent')) return BarcodeContentKind.event;
    if (lower.startsWith('geo:')) return BarcodeContentKind.location;
    if (lower.startsWith('bitcoin:') ||
        lower.startsWith('ethereum:') ||
        lower.startsWith('litecoin:')) {
      return BarcodeContentKind.crypto;
    }
    return BarcodeContentKind.text;
  }
}

enum BarcodeContentKind {
  url,
  wifi,
  email,
  phone,
  sms,
  contact,
  event,
  location,
  crypto,
  text,
}
