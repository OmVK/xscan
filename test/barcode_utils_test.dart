import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xscan/core/services/barcode_utils.dart';

void main() {
  group('BarcodeUtils.contentKind', () {
    test('detects URL with https', () {
      expect(BarcodeUtils.contentKind('https://example.com'), BarcodeContentKind.url);
    });

    test('detects URL with http', () {
      expect(BarcodeUtils.contentKind('http://example.com'), BarcodeContentKind.url);
    });

    test('detects WiFi', () {
      expect(BarcodeUtils.contentKind('WIFI:T:WPA;S:MyNetwork;P:password123;;'), BarcodeContentKind.wifi);
    });

    test('detects email with mailto', () {
      expect(BarcodeUtils.contentKind('mailto:user@example.com'), BarcodeContentKind.email);
    });

    test('detects phone', () {
      expect(BarcodeUtils.contentKind('tel:+15551234567'), BarcodeContentKind.phone);
    });

    test('detects SMS', () {
      expect(BarcodeUtils.contentKind('smsto:+15551234567:Hello'), BarcodeContentKind.sms);
    });

    test('detects vCard contact', () {
      expect(BarcodeUtils.contentKind('BEGIN:VCARD\nVERSION:3.0\nFN:John\nEND:VCARD'), BarcodeContentKind.contact);
    });

    test('detects calendar event', () {
      expect(BarcodeUtils.contentKind('BEGIN:VEVENT\nSUMMARY:Meeting\nEND:VEVENT'), BarcodeContentKind.event);
    });

    test('detects geo location', () {
      expect(BarcodeUtils.contentKind('geo:37.7749,-122.4194'), BarcodeContentKind.location);
    });

    test('detects Bitcoin crypto', () {
      expect(BarcodeUtils.contentKind('bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'), BarcodeContentKind.crypto);
    });

    test('detects Ethereum crypto', () {
      expect(BarcodeUtils.contentKind('ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f2bD38'), BarcodeContentKind.crypto);
    });

    test('detects plain text', () {
      expect(BarcodeUtils.contentKind('Hello World'), BarcodeContentKind.text);
    });

    test('handles whitespace', () {
      expect(BarcodeUtils.contentKind('  https://example.com  '), BarcodeContentKind.url);
    });
  });

  group('BarcodeUtils.formatLabel', () {
    test('labels QR Code', () {
      expect(BarcodeUtils.formatLabel(BarcodeFormat.qrCode), 'QR Code');
    });

    test('labels EAN-13', () {
      expect(BarcodeUtils.formatLabel(BarcodeFormat.ean13), 'EAN-13');
    });

    test('labels Code 128', () {
      expect(BarcodeUtils.formatLabel(BarcodeFormat.code128), 'Code 128');
    });

    test('labels UPC-A', () {
      expect(BarcodeUtils.formatLabel(BarcodeFormat.upcA), 'UPC-A');
    });

    test('labels unknown as Barcode', () {
      expect(BarcodeUtils.formatLabel(BarcodeFormat.all), 'Barcode');
    });
  });
}
