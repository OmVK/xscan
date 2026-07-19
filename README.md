<div align="center">

# XScan

**A privacy-first document scanner, QR generator and full PDF toolkit for Android.**

Scan, edit, sign, convert and organise your documents — completely offline.

[![Download](https://img.shields.io/badge/Download-Latest%20Release-6C63FF?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)](https://github.com/OmVK/xscan/releases/latest)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## Download

Grab the latest APK from the [**Releases page**](https://github.com/OmVK/xscan/releases/latest):

| File | Best for | Size |
| --- | --- | --- |
| `app-release.apk` | **Any Android phone** — universal build | ~165 MB |

**To install:** enable *"Install unknown apps"* for your browser or file manager, then open the downloaded APK.

---

## Features

### Scanning
- Native **ML Kit** document scanner with automatic edge detection
- Multi-page capture and batch scanning
- On-device **OCR** (text recognition) — Latin, Chinese, Devanagari, Japanese & Korean scripts
- Barcode & QR **scanning** from the camera or gallery, with smart content detection (URL, Wi-Fi, VIN, ISBN, etc.)

### QR Generator
- 16 content types: URL, text, Wi-Fi, contact, email, SMS, phone, location, event, crypto, WhatsApp, Instagram, and more
- **Design styles** (Classic, Rounded, Dots, Smooth), curated **color themes**, custom colors, and a **center logo**
- Save or share as a high-resolution PNG

### PDF Toolkit
- **Editor** — add text, signatures, stamps, highlights and freehand drawing
- **Fill forms** — complete interactive PDF form fields
- Merge, split, compress, rotate, duplicate & reorder pages
- Watermark, password-protect, flatten, and export to **PDF/A** (archival)
- Convert **images → PDF**, **PDF → images**, and **PDF → text**
- Create **searchable PDFs** from scans

### Images
- Built-in image editor: crop, rotate, flip, auto-enhance, filters and adjustments
- Convert between PNG, JPG, TIFF, BMP & WEBP

### Organisation & Privacy
- Folders, tags, notes and favorites
- **Archive**, **Trash** (with secure file wiping) and a **Hidden vault** protected by AES-256-CBC encryption
- **Biometric app lock**
- Local **backup & restore** to a `.zip` (with zip-slip protection)
- **100% offline** — AI assistance, translation and text-to-speech all run on-device

### Security
- **AES-256 PDF encryption** via Syncfusion (replaced deprecated RC4-128)
- **AES-256-CBC vault encryption** for hidden documents (key stored in `flutter_secure_storage`)
- **Zip-slip protection** prevents path traversal attacks during backup restore
- **URL scheme validation** — only `http`/`https` links can be opened externally
- **WiFi QR escaping** handles special characters in network names

### Extras
- Offline **AI assistant**: auto-detect document type, suggest titles/folders, summarise, extract invoice/receipt data, and answer questions
- **Translation** (on-device ML Kit) & **text-to-speech**
- **Print** any PDF
- Register as an Android PDF handler — open PDFs directly from your browser or file manager
- **Material You** dynamic theming with a glassmorphism UI (light & dark)

---

## Build from source

### Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.12.2`)
- Android SDK + a JDK 17
- An Android device or emulator

### Setup
```bash
git clone https://github.com/OmVK/xscan.git
cd xscan
flutter pub get

# Generate the Isar database code
dart run build_runner build --delete-conflicting-outputs
```

### Run
```bash
flutter run
```

### Build release APKs
```bash
# Universal (all CPU types) — one file installs anywhere
flutter build apk --release

# Split per architecture — smaller, one APK per CPU type
flutter build apk --release --split-per-abi
```
Output lands in `build/app/outputs/flutter-apk/`.

### Test & analyse
```bash
flutter analyze
flutter test
```

---

## Tech stack

| Area | Packages |
| --- | --- |
| State management | `flutter_riverpod` |
| Database | `isar`, `isar_flutter_libs` |
| Scanning & OCR | `mobile_scanner`, `google_mlkit_text_recognition`, `cunning_document_scanner` |
| PDF | `syncfusion_flutter_pdf`, `syncfusion_flutter_pdfviewer`, `pdf`, `pdfx`, `printing` |
| QR | `qr_flutter` |
| Imaging | `image`, `image_cropper`, `image_picker` |
| On-device AI | `google_mlkit_translation`, `flutter_tts` |
| Security | `flutter_secure_storage`, `encrypt` (AES-256-CBC vault encryption) |
| Platform | `local_auth`, `receive_sharing_intent`, `share_plus`, `dynamic_color` |

---

## Project structure

```
lib/
├── core/
│   ├── data/           # Isar models & database service
│   ├── providers/      # Riverpod providers
│   ├── services/       # PDF, image, AI, OCR, backup, vault, print, etc.
│   └── theme/          # App theming (dynamic color)
├── features/
│   ├── auth/           # Biometric lock
│   ├── dashboard/      # Home, tools & file shelves
│   ├── document/       # Document detail & AI assistant
│   ├── onboarding/
│   ├── qr/             # QR generator
│   ├── scanner/        # Camera & OCR
│   ├── settings/
│   └── tools/          # PDF & image tool screens
└── main.dart
```

---

## License

Released under the [MIT License](LICENSE).
