<div align="center">

# XScan

**A privacy-first document scanner, QR generator, live PDF editor, and full document toolkit for Android.**

Scan, edit, sign, convert, translate, and protect your documents — completely offline.

[![Download](https://img.shields.io/badge/Download-v2.0.1%20Release-6C63FF?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v2.0.1)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v2.0.1)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## Download

Grab the latest production APK from the [**Releases page**](https://github.com/OmVK/xscan/releases/tag/v2.0.1):

| File | Best for | Size |
| --- | --- | --- |
| `app-arm64-v8a-release.apk` | **64-bit ARM** — modern phones (recommended) | ~63 MB |
| `app-armeabi-v7a-release.apk` | **32-bit ARM** — older phones | ~51 MB |
| `app-x86_64-release.apk` | **x86 64-bit** — emulators | ~67 MB |

**To install:** Enable *"Install unknown apps"* for your browser or file manager, then open the downloaded APK.

---

## What's New in v2.0.1

### 🔧 Build & Stability Release
- **Fixed Android build pipeline**: upgraded the Gradle toolchain to a compatible AGP/Gradle combo, added namespace + `compileSdk` handling for legacy plugins (e.g. `isar_flutter_libs`), and generated the missing Isar model code (`scan_document.g.dart`) in CI — release APKs now build cleanly from a fresh checkout.
- **Fixed camera scan crash**: `newDoc` is now properly in scope when opening the saved document after scanning.
- **Fixed encrypted backup export**: the app database is now correctly packed into `.zip`/`.enc` backups.
- **Fixed OCR scan title** and PDF text extraction edge cases; decryption helper now returns the expected byte type (AES-256-GCM vault & backup remain fully backward compatible).
- **Syncfusion licensing**: no license key needed on Syncfusion Flutter ≥ 18.3 (XScan uses 34.x) — removed the obsolete registration call.
- **CI/CD**: unit tests (`crypto_utils`, `path_safety`) now run on every push/PR; Isar code generation added to the release build jobs.

> [!WARNING]
> **Vault format migration**: Files hidden with app versions before v2.0.0 are not decryptable by newer builds (they fail safely, nothing is corrupted). **Unhide any hidden documents on the old build before updating.**

---

## What's New in v2.0.0

### 🎯 Studio QR Creator Suite
- **Authentic Brand Logos**: Official vector rendering for **WhatsApp** (white background, green speech bubble) and **Instagram** (multi-color gradient background with white camera glyph).
- **Call-To-Action Banner Badges**: Renders custom CTA text badges (`"SCAN ME"`, `"CONNECT TO WI-FI"`, `"CHAT ON WHATSAPP"`) natively on canvas exports.
- **Dual-Tone Eye Corner Customizer**: Independent color picker for QR eye corners (e.g. Electric Cyan eyes with Dark Navy QR body).
- **Printable A4 Multi-QR PDF Sheets**: 1-tap export to A4 PDF with 6-up grid layout, cut borders, and titles for stickers, table tents, and event badges.
- **100% Native Module Clearing**: QR matrix dots form a clean surrounding ring around the center logo with zero overlap.

### 📝 On-Page Interactive OCR Canvas
- **Dynamic Font Resizing**: Font size slider (`8pt` – `48pt`), `A-`/`A+` step controls, 2-finger pinch scaling, and 1-tap quick resize toolbar chips.
- **Multi-Line Wrapping**: Wrapped text support with zero text cutoff or hidden lines on multi-line text and newlines (`\n`).
- **Direct Canvas Editing**: Tap any recognized sentence on top of the document photo to edit, reflow, scale, or replace text live.

### 📂 Document Library Context Menu
- **Long-Press Executive Action Sheet**: Long-press any document tile to immediately **Share PDF**, **Delete Document**, or **Toggle Favorites** with medium haptic feedback.
- **Pure 1-Page Scanned PDFs**: Streamlined PDF engine producing pure scanned pages without trailing plain text pages.

### 🔐 AES-256-GCM Encrypted Vault & Backups
- **Authenticated Vault Encryption**: AES-256-GCM encryption for hidden documents (replaces previous biometric-gated-only approach).
- **Encrypted Backups**: `.enc` backup format using AES-256-GCM with PBKDF2-HMAC-SHA256 key derivation and zip-slip protection.

### ⚙️ CI/CD with GitHub Actions
- Automated build pipeline: every push to `main` runs analysis + tests; every version tag builds split-per-ABI APKs, an AAB, and automatically creates a GitHub Release.

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
- **AES-256-GCM authenticated vault encryption** for hidden documents
- **Biometric app lock** (Fingerprint / Face Unlock)
- **Encrypted backups** (`.enc`, AES-256-GCM) with PBKDF2-HMAC-SHA256 key derivation and zip-slip protection
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

# Generate the Isar model code (scan_document.g.dart, git-ignored)
dart run build_runner build --delete-conflicting-outputs

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
| Security | `flutter_secure_storage`, `encrypt` (AES-256-GCM vault & backups) |
| Platform | `local_auth`, `receive_sharing_intent`, `share_plus`, `dynamic_color` |

---

## Verify, Sign & Release

### 1. Run the checks
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # isar model code
flutter analyze
flutter test     # includes the pure crypto + zip-slip unit tests (no device needed)
```

CI (`.github/workflows/ci.yml`) runs analyze + tests on every PR/push to `main` and
builds split-per-ABI release APKs on `main` and AABs on tags.

### 2. Syncfusion license
XScan uses Syncfusion's commercial Flutter plugins (`syncfusion_flutter_pdf` /
`syncfusion_flutter_pdfviewer`, version 34.x). Since Syncfusion Flutter 18.3.0.x,
license key registration is **no longer required** — the controls run without a
key, subject to the commercial or community license terms. See
https://help.syncfusion.com/flutter/licensing/overview for details.

### 3. Create a release keystore
Release builds **hard-fail** if `android/key.properties` is missing. Generate one once and keep it safe:

```bash
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Then create `android/key.properties`:
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=upload-keystore\.jks
```

*`key.properties` and `*.jks` are git-ignored (`android/.gitignore`) — never commit them.*

### 4. Sign via CI (optional)
Add these repository secrets to let CI produce signed artifacts automatically:
`KEYSTORE_BASE64` (base64 of `upload-keystore.jks`), `KEYSTORE_PASSWORD`,
`KEYSTORE_ALIAS`.

---

## License

Released under the [MIT License](LICENSE).
