# XScan — Roadmap & Future Upgrades

A running list of features and improvements to implement in future releases.
Check items off as they ship and move them to the changelog.

Legend: **Effort** = S (small) / M (medium) / L (large) · **Impact** = ⭐ (nice) → ⭐⭐⭐ (major)

---

## Quick wins (low effort, high impact)

- [ ] **Cloud backup** — Google Drive / Dropbox sync (currently local `.zip` only) · **L / ⭐⭐⭐**
- [ ] **Auto-capture in scanner** — snap automatically when edges are stable (hands-free multi-page) · **M / ⭐⭐⭐**
- [ ] **Batch export/share** — select multiple docs → merge / share / export at once · **S / ⭐⭐**
- [ ] **PDF page thumbnails grid** in the viewer for fast navigation · **S / ⭐⭐**
- [ ] **Recent files + search history** on the dashboard · **S / ⭐⭐**
- [ ] **App shortcuts** — long-press launcher icon → "Scan", "Import PDF" · **S / ⭐**

## Medium effort

- [ ] **Home-screen widget** — one-tap "Scan now" · **M / ⭐⭐**
- [ ] **iOS support** — codebase is ~90% portable · **L / ⭐⭐⭐**
- [ ] **OCR improvements** — copy-by-region, searchable-text overlay on original scan, table/column detection · **M / ⭐⭐**
- [ ] **Digital signatures (real PKI)** — certificate-based signing (legal/business docs) · **L / ⭐⭐⭐**
- [ ] **Smart file naming** — auto-name from OCR (dates, vendor, invoice #) using existing `AiService` · **S / ⭐⭐**
- [ ] **Compression presets** — Low / Medium / High with size preview before saving · **S / ⭐⭐**
- [ ] **eSign flow** — send a PDF for signature / add signature fields · **L / ⭐⭐**

## Larger / strategic

- [ ] **True encrypted vault** — AES-encrypted storage for the Hidden shelf (currently biometric-gated only; files not encrypted at rest) · **L / ⭐⭐⭐**
- [ ] **Play Store release** — switch to `.aab` App Bundle, privacy policy, data-safety form, versioning · **M / ⭐⭐⭐**
- [ ] **CI/CD** — GitHub Actions to auto-build + attach APKs to releases on tag push · **M / ⭐⭐⭐**
- [ ] **Optional online AI mode** — LLM-powered summaries / Q&A / translation as opt-in (offline stays default) · **L / ⭐⭐**
- [ ] **Multi-language app UI (i18n)** — UI is English-only today · **M / ⭐⭐**
- [ ] **Tablet / landscape layouts** and accessibility polish · **M / ⭐⭐**

## Technical debt

- [ ] **Kotlin Gradle Plugin warnings** — `mlkit`, `mobile_scanner`, `pdfx` will break on future Flutter versions; track upstream updates · **M / ⭐⭐**
- [ ] **APK size** — ~60 MB arm64 is heavy; trim ML Kit models / use on-demand model download · **M / ⭐⭐**
- [ ] **Widget/integration tests** — only 9 unit tests today; add golden tests for key screens · **M / ⭐⭐**

---

## Suggested next 3 (highest impact first)

1. **CI/CD with GitHub Actions** — automate the build + release pipeline (self-contained, pays off every build).
2. **Cloud backup** — the #1 missing feature vs. commercial scanners.
3. **Encrypted vault** — turns "Hidden" from cosmetic into genuinely secure.

---

## Done (moved from roadmap)

_Ship a feature? Move it here with the release version._

- v1.0.0 — Initial public release: scanner, OCR, QR generator (designs/themes/logo), full PDF toolkit
  (editor, merge, split, compress, watermark, protect, fill forms, flatten, PDF/A, to-images, to-text),
  image editor & format conversion, favorites/archive/trash/hidden shelves, biometric lock,
  offline AI assistant, translation, TTS, print, local backup/restore, Material You theming.
