<div align="center">

# XScan

**A privacy-first document scanner, QR generator, live PDF editor, and full document toolkit for Android.**

Scan, edit, sign, convert, translate, and protect your documents — completely offline.

[![Download](https://img.shields.io/badge/Download-v1.3.0%20Release-6C63FF?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v1.3.0)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v1.3.0)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## Download

Grab the latest production APK from the [**Releases page**](https://github.com/OmVK/xscan/releases/tag/v1.3.0):

| File | Best for | Size |
| --- | --- | --- |
| `app-release.apk` | **Any Android phone** — universal release build | ~167 MB |

**To install:** Enable *"Install unknown apps"* for your browser or file manager, then open the downloaded APK.

---

## What's New in v1.3.0

### 🎯 Studio QR Creator Suite
- **Authentic Brand Logos**: Official vector rendering for **WhatsApp** (white background, green speech bubble, green phone handset tilted at 45°) and **Instagram** (multi-color purple/red/yellow gradient background with white camera lens & flash glyph).
- **Call-To-Action Banner Badges ("SCAN ME")**: Renders custom CTA text badges (`"SCAN ME"`, `"CONNECT TO WI-FI"`, `"CHAT ON WHATSAPP"`) natively on canvas exports.
- **Dual-Tone Eye Corner Customizer**: Independent color picker for QR eye corners (e.g. Electric Cyan eyes with Dark Navy QR body).
- **Printable A4 Multi-QR PDF Sheets**: 1-tap export to A4 PDF with 6-up grid layout complete with cut borders and titles for stickers, table tents, and event badges.
- **100% Native Module Clearing**: Omits QR matrix dots in the center region so dots form a clean surrounding ring around the center logo with zero overlap.

### 📝 On-Page Interactive OCR Canvas
- **Dynamic Font Resizing**: Font size slider (`8pt` – `48pt`), `A-`/`A+` step controls, 2-finger pinch scaling, and 1-tap quick resize toolbar chips (`[ Enlarge + ]`, `[ Shrink - ]`, `[ Wider ↔ ]`).
- **Multi-Line Wrapping**: Wrapped text support with zero text cutoff or hidden lines on multi-line text and newlines (`\n`).
- **Direct Canvas Editing**: Tap any recognized sentence on top of the document photo to edit, reflow, scale, or replace text live.

### 📂 Document Library Context Menu
- **Long-Press Executive Action Sheet**: Long-press any document tile in the grid or list view to immediately **Share PDF**, **Delete Document**, or **Toggle Favorites** with medium haptic feedback.
- **Pure 1-Page Scanned PDFs**: Streamlined PDF engine producing pure scanned pages without trailing plain text pages.

---

## Full Features

### Scanning & Camera
- Native **ML Kit** document scanner with automatic edge detection
- Multi-page capture and batch scanning
- On-device **OCR** with entity extraction & TTS
- Barcode & QR **scanning** from camera or gallery (URL, Wi-Fi, VIN, ISBN, etc.)

### QR & Barcode Generator
- 16 content types: URL, text, Wi-Fi, contact, email, SMS, phone, location, event, crypto, WhatsApp, Instagram, etc.
- **Design styles** (Classic, Rounded, Dots, Smooth), curated **color themes**, custom dual-tone eye colors, CTA frame banners, and center logo shield
- Real-time high-resolution PNG export & printable A4 PDF sheet generation

### PDF Toolkit & Editor
- **Live Editor** — text, signatures, stamps, highlights, redaction, eraser, and freehand drawing
- **Fill forms** — complete interactive PDF form fields
- Merge, split, compress, rotate, duplicate & reorder pages
- Watermark, password-protect, flatten, and export to **PDF/A**
- Convert **images → PDF**, **PDF → images**, and **PDF → text**
- Create **searchable PDFs** from scans

### Security & Privacy
- **AES-256 PDF encryption** via Syncfusion
- **AES-256-CBC vault encryption** for hidden documents
- **Biometric app lock** (Fingerprint / Face Unlock)
- Local **backup & restore** to `.zip` with zip-slip protection
- **100% offline** — all OCR, translation, and TTS run completely on-device

---

## Build from Source

### Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.12.2`)
- Android SDK + JDK 17
- Connected Android device or emulator

### Setup & Run
```bash
git clone https://github.com/OmVK/xscan.git
cd xscan
flutter pub get

# Run in debug mode
flutter run
```

### Build Production Release APK
```bash
flutter build apk --release
```
Output lands in `build/app/outputs/flutter-apk/app-release.apk`.

---

## Tech Stack

| Area | Packages |
| --- | --- |
| State Management | `flutter_riverpod` |
| Database | `isar`, `isar_flutter_libs` |
| Scanning & OCR | `mobile_scanner`, `google_mlkit_text_recognition`, `cunning_document_scanner` |
| PDF Engine | `syncfusion_flutter_pdf`, `syncfusion_flutter_pdfviewer`, `pdf`, `pdfx`, `printing` |
| QR Code | `qr_flutter`, `barcode_widget` |
| Imaging | `image`, `image_cropper`, `image_picker` |
| On-Device AI | `google_mlkit_translation`, `flutter_tts` |
| Security | `flutter_secure_storage`, `encrypt` (AES-256-CBC vault) |
| Platform | `local_auth`, `receive_sharing_intent`, `share_plus`, `dynamic_color` |

---

## License

Released under the [MIT License](LICENSE).
