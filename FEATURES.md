# XScan - Complete Feature List

Status: ✅ = Implemented | ⚠️ = Partial | ❌ = Missing

---

## Scanning
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Document Scanner | ✅ | Auto edge-detection, multi-page batch (CunningDocumentScanner) |
| 2 | Multi-page Preview | ✅ | Horizontal scroll, per-page delete |
| 3 | Barcode / QR Scanner | ✅ | Live camera with animated scan frame (MobileScanner) |
| 4 | Gallery Barcode Scan | ✅ | Image picker + analyzeImage |
| 5 | Batch Barcode Scan | ✅ | Continuous mode with deduplication |
| 6 | Batch Export (CSV) | ✅ | CSV with headers |
| 7 | Batch Export (Text) | ✅ | Formatted text file |
| 8 | Batch Share | ✅ | System share sheet |
| 9 | Scan Result Overlay | ✅ | Inline popup, not bottom sheet |
| 10 | Barcode Format Badge | ✅ | Colored badge with format name |
| 11 | Quick Actions | ✅ | Open URL, WiFi, Call, Email, SMS, Map, Copy, Save |
| 12 | Animated Scan Frame | ✅ | Pulsing line + corner accents |
| 13 | Batch Count Badge | ✅ | Circular badge in top bar |
| 14 | OCR Text Extraction | ✅ | ML Kit on-device |
| 15 | OCR from Gallery | ✅ | Pick image for OCR |
| 16 | Multi-language OCR | ✅ | 5 scripts with language picker bottom sheet |

## QR Code Generation
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 17 | URL QR Code | ✅ | |
| 18 | Text QR Code | ✅ | |
| 19 | Wi-Fi QR Code | ✅ | SSID, password, encryption type |
| 20 | Contact QR Code | ✅ | vCard 3.0 format |
| 21 | Email QR Code | ✅ | mailto: with subject/body |
| 22 | SMS QR Code | ✅ | SMSTO: format |
| 23 | Phone QR Code | ✅ | tel: URI |
| 24 | Location QR Code | ✅ | geo: URI |
| 25 | Calendar Event QR Code | ✅ | vEvent format |
| 26 | Crypto Wallet QR Code | ✅ | BTC, ETH, LTC |
| 27 | WhatsApp QR Code | ✅ | wa.me link |
| 28 | Instagram QR Code | ✅ | instagram.com profile |
| 29 | Facebook QR Code | ✅ | facebook.com profile |
| 30 | LinkedIn QR Code | ✅ | Handles in/ and company/ prefixes |
| 31 | Telegram QR Code | ✅ | t.me link |
| 32 | Discord QR Code | ✅ | Invite code or full URL |
| 33 | QR Design Styles (12) | ✅ | Classic, Sharp, Rounded, Smooth, Hybrid, Dots, Bubbles, Diamond, Star, Rivet, Soft Square, Pill |
| 34 | QR Color Themes (23) | ✅ | Ink through Ocean Deep |
| 35 | Gradient Themes | ✅ | Rendered via BlendMode.srcIn compositing — white QR on transparent, gradient applied as background |
| 36 | Custom Colors | ✅ | RGB slider ColorPicker dialog with live preview |
| 37 | Center Logo Embedding | ✅ | Add/Change/Remove, QrEmbeddedImageStyle |
| 38 | Logo Size Control | ✅ | Slider 10%-35% |
| 39 | Logo Clearance Zone | ✅ | qr_flutter auto-clears modules |
| 40 | Background Image / Wallpaper | ✅ | Auto-crop, semi-transparent overlay |
| 41 | Style Presets | ✅ | Save/Load/Delete presets as JSON |
| 42 | High-Resolution Export | ✅ | Up to 2048px PNG |
| 43 | QR Export Size Selector | ✅ | 256, 512, 1024, 2048 |
| 44 | Quiet Zone Toggle | ✅ | |

## Batch QR Generation
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 45 | CSV Import | ✅ | 1/2/3-column CSV parsing |
| 46 | Batch QR as PNG Files | ✅ | 512px per item |
| 47 | Batch QR as PDF | ✅ | Syncfusion PDF with labels |

## QR / Barcode History
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 48 | QR History | ✅ | JSON-backed, thumbnail grid |
| 49 | QR History Search | ✅ | By name or content |
| 50 | QR History Filter | ✅ | By type (URL, Text, Wi-Fi, etc.) |
| 51 | QR from PDF | ✅ | Extract text → generate QR |
| 52 | Barcode History | ✅ | Riverpod provider, filtered list |
| 53 | Barcode History Search | ✅ | By value or format |
| 54 | Barcode History Filter | ✅ | By format (EAN-13, UPC-A, etc.) |

## Barcode Generation (1D)
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 55 | Code 128 | ✅ | |
| 56 | Code 39 | ✅ | |
| 57 | Code 93 | ✅ | |
| 58 | EAN-13 | ✅ | With digit validation |
| 59 | EAN-8 | ✅ | With digit validation |
| 60 | UPC-A | ✅ | With digit validation |
| 61 | UPC-E | ✅ | With digit validation |
| 62 | Codabar | ✅ | With digit validation |
| 63 | ITF | ✅ | With digit validation |
| 64 | ISBN | ✅ | 10/13 digit validation |
| 65 | Barcode Height Slider | ✅ | 60-250px |
| 66 | Barcode Bar Width | ✅ | Slider scales BarcodeWidget width proportionally |
| 67 | Show Text Toggle | ✅ | |
| 68 | Foreground Color | ✅ | 12-color picker |
| 69 | Background Color | ✅ | 12-color picker |
| 70 | Barcode Save as PNG | ✅ | 3x pixel ratio |
| 71 | Barcode Share | ✅ | System share sheet |

## PDF Tools
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 72 | PDF Editor | ✅ | Text, images, signatures, highlights, drawings, redact, OCR overlay |
| 73 | Merge PDFs | ✅ | Reorderable list, multi-select |
| 74 | Split PDF | ✅ | Ranges, every page, every N, by bookmarks |
| 75 | Compress PDF | ✅ | Before/after comparison, percentage reduction |
| 76 | Organize Pages | ✅ | Reorder, duplicate, delete with confirmation |
| 77 | Rotate Pages | ✅ | Per-page quarter-turn, rotation badges |
| 78 | Watermark | ✅ | Diagonal text, opacity/angle/color |
| 79 | Watermark Templates | ✅ | 8 pre-built stamps + custom text |
| 80 | Page Numbers | ✅ | 6 positions, format string, font/color |
| 81 | Protect PDF | ✅ | AES-256, user/owner passwords, permission restrictions |
| 82 | Redact PDF | ✅ | Secure rasterization + color picker (black/white/red/blue/green/yellow) |
| 83 | Flatten PDF | ⚠️ | Service method works, exposed as one-click dashboard action — no dedicated screen |
| 84 | PDF/A Archive | ⚠️ | Service method works, exposed as one-click action — no dedicated screen, rasterizes content |
| 85 | Images to PDF | ✅ | Page size (A4/Letter/Square), landscape toggle |
| 86 | Searchable PDF | ✅ | Invisible OCR text layer |
| 87 | PDF to Images | ✅ | DPI selector (72-384), PNG/JPEG format |
| 88 | PDF to Text | ✅ | Extract, copy, export .txt |
| 89 | Fill Forms | ✅ | Text + checkbox fields, flatten option |
| 90 | Bookmarks | ✅ | CRUD, reorder, confirmation delete |
| 91 | Print PDF | ✅ | printing plugin |
| 92 | PDF Metadata | ✅ | Author, title, subject, keywords, creator, producer |
| 93 | Compare PDFs | ✅ | Side-by-side/stacked view (NOT in FEATURES.md — added) |

## Image Tools
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 94 | Image Editor | ✅ | Crop, rotate, flip |
| 95 | Auto Enhance | ✅ | One-tap contrast+brightness+sharpness |
| 96 | Image Filters | ✅ | Magic, Vivid, Cool, Warm, Vintage, Invert |
| 97 | Brightness / Contrast / Saturation | ✅ | Sliders -100..+100 |
| 98 | Sharpness / Blur | ✅ | Gaussian blur + custom convolution |
| 99 | Format Conversion | ⚠️ | PNG/JPG/TIFF/BMP/WEBP — WEBP falls back to PNG on some platforms |

## Security & Privacy
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 100 | Hidden Vault | ✅ | AES-256-CBC with random IV, key in FlutterSecureStorage |
| 101 | Biometric App Lock | ✅ | Fingerprint/face auth |
| 102 | Secure File Wiping | ✅ | 4096-byte zero overwrite before delete |
| 103 | Backup to ZIP | ✅ | AES-256-CBC encrypted ZIP with PBKDF2 key derivation, optional password |
| 104 | Restore from ZIP | ✅ | Zip-slip protection, path validation |
| 105 | AES-256 PDF Encryption | ✅ | Per-document password setting |

## Organisation
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 106 | Folders | ✅ | Folder filter chips in dashboard Home tab |
| 107 | Tags | ✅ | Tag filter chips in dashboard Home tab |
| 108 | Notes | ✅ | Edit dialog, included in search |
| 109 | Favorites | ✅ | Toggle with haptic, Favorites shelf |
| 110 | Archive | ✅ | Toggle, Archive shelf |
| 111 | Trash | ✅ | Soft-delete, restore, empty trash, secure wipe |
| 112 | Hidden Documents | ✅ | Biometric gate, encrypted storage |

## AI & Translation
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 113 | Document Type Detection | ⚠️ | Heuristic keyword scoring (7 types) — not ML model |
| 114 | Title Suggestions | ⚠️ | Pattern-based — not ML model |
| 115 | Folder Suggestions | ⚠️ | Static type→folder mapping — not adaptive |
| 116 | Document Summarization | ⚠️ | Extractive only (sentence selection) — not abstractive |
| 117 | Invoice / Receipt Extraction | ✅ | Structured data display in document detail AI Assistant |
| 118 | Q&A | ⚠️ | Single best sentence return — no multi-sentence answers |
| 119 | On-device Translation | ✅ | ML Kit, 14 languages |
| 120 | Text-to-Speech | ✅ | flutter_tts |

## Dashboard & UI
| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 121 | Material You Theming | ✅ | DynamicColorBuilder, harmonized colors |
| 122 | Glassmorphism UI | ✅ | BackdropFilter, translucent panels |
| 123 | Light / Dark Mode | ✅ | System/Light/Dark with persistence |
| 124 | Document Grid View | ✅ | MasonryGridView, staggered heights |
| 125 | Document List View | ✅ | Grid/list toggle on Home tab |
| 126 | Category Grouping | ✅ | All, Receipts, Documents, Notes, Barcodes |
| 127 | Shelf Selector | ✅ | Library, Favorites, Archive, Trash, Hidden |
| 128 | Search | ✅ | Full-text with 300ms debounce |
| 129 | Onboarding | ✅ | 4-page guided tour |
| 130 | Tool Grid | ✅ | 3 sections, 29 tools |
| 131 | Share Handling | ✅ | receive_sharing_intent |
| 132 | File Import | ✅ | Multiple import paths |
| 133 | Print Support | ✅ | printing plugin |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Implemented | **118** |
| ⚠️ Partial | **15** |
| ❌ Missing | **0** |
| **Total** | **133** |

### Top Priority Fixes Needed

**Missing UI (feature exists but inaccessible):**
1. **#83 Flatten PDF** — no dedicated screen
2. **#84 PDF/A Archive** — no dedicated screen

**UX Gaps:**
3. **#99 Format Conversion** — WEBP platform fallback
4. **#113-118 AI Features** — all heuristic, not real ML
