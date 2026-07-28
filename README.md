<div align="center">

# XScan

**A privacy-first document scanner, QR generator, live PDF editor, and full document toolkit for Android.**

Scan, edit, sign, convert, translate, and protect your documents — completely offline.

[![Download](https://img.shields.io/badge/Download-v1.2.0%20Release-6C63FF?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v1.2.0)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/tag/v1.2.0)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## Download

Grab the latest production APK from the [**Releases page**](https://github.com/OmVK/xscan/releases/tag/v1.2.0):

| File | Best for | Size |
| --- | --- | --- |
| `app-release.apk` | **Any Android phone** — universal release build | ~167 MB |

**To install:** Enable *"Install unknown apps"* for your browser or file manager, then open the downloaded APK.

---

## What's New in v1.2.0

### 💎 Executive Dark Glass UI System
- **Executive Dark Slate Backdrop**: Clean canvas (`#090C15` to `#0B0E17`) featuring a custom 3D metallic **XSCAN** brand wallpaper and atmospheric cyan/indigo ambient mesh glows.
- **Apple / macOS Frosted Glass Cards**: `18px` backdrop blur (`BackdropFilter`), 1.0px specular glass borders (`Colors.white.withValues(alpha: 0.12)`), and high-contrast typography.
- **Executive Greeting & Status Pills**: Dynamic time-of-day greeting (`Good Morning / Afternoon / Evening, Executive`) with sun/moon indicators and biometric security badges (`🔒 Biometric Vault Active`).
- **1-Tap Hero Quick Action Bar**: Instant launcher for **Scan Doc**, **Edit PDF**, **Scan QR**, and **Quick OCR**.

### ✏️ PDF Editor Real-Time Touch Preview & Drawing
- **Live Finger Touch Cursor**: Renders a glowing touch pointer ring beneath your finger in real time during drag/draw gestures.
- **Smooth Bezier Freehand Ink**: Quadratic bezier curve interpolation for natural drawing with a dynamic stroke weight slider (`1px` – `20px`).
- **Dedicated Eraser Tool**: Delete freehand ink strokes and annotations easily.
- **Normalized Drag Rectangles**: Smooth live highlight and redaction bounding boxes when dragging backwards or diagonally.

### 📱 100% Scannable QR Generator
- **Level H Error Recovery (30%)**: Enforces `QrErrorCorrectLevel.H` so QR codes with embedded center logos retain 100% data integrity.
- **White Background Logo Shield**: Protective white background shield container isolating center logo pixels from surrounding dark QR modules.
- **High-Contrast Wallpaper Backing Card**: Automatically renders a high-contrast backing card when custom wallpaper images are selected.
- **1-Tap Brand Presets**: Quick logos for WhatsApp, Instagram, Facebook, LinkedIn, Wi-Fi, Phone, Email, Location, and Globe.

### 🔬 Upgraded OCR Engine (Text-to-Speech & Translation)
- **Structured Entity Extraction**: Automatically extracts and highlights **Emails**, **Phone Numbers**, **URLs**, **Dates**, and **Amounts / Prices** from scanned text.
- **Text-To-Speech (TTS) Reader**: Audio player controls (`flutter_tts`) to listen to recognized document text out loud.
- **On-Device Machine Translation**: Translates OCR text locally into 50+ languages using `google_mlkit_translation` without an internet connection.
- **Multi-Script Engine**: Supports Latin, Devanagari, Japanese, Korean, and Chinese character recognition.

---

## Full Features

### Scanning & Camera
- Native **ML Kit** document scanner with automatic edge detection
- Multi-page capture and batch scanning
- On-device **OCR** with entity extraction & TTS
- Barcode & QR **scanning** from camera or gallery (URL, Wi-Fi, VIN, ISBN, etc.)

### QR & Barcode Generator
- 16 content types: URL, text, Wi-Fi, contact, email, SMS, phone, location, event, crypto, WhatsApp, Instagram, etc.
- **Design styles** (Classic, Rounded, Dots, Smooth), curated **color themes**, custom colors, and center logo shield
- Real-time high-resolution PNG export

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

# Generate Isar database code
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
| Security | `flutter_secure_storage`, `encrypt` (AES-256-CBC vault) |
| Platform | `local_auth`, `receive_sharing_intent`, `share_plus`, `dynamic_color` |

---

## License

Released under the [MIT License](LICENSE).
