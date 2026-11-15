# OCR Evaluation Package — AI Form & Vault

**Goal:** Decide whether to replace/add **PaddleOCR** alongside your current **Google ML Kit** OCR for Indian ID documents (Aadhaar, PAN, Voter ID, Driving Licence, Passport, Bank passbook) — including regional languages.

---

## What's in this package

| File | What it does |
|---|---|
| `OCR_EVALUATION_REPORT.md` | Full comparison: PaddleOCR vs ML Kit, model sizes, accuracy expectations, recommendation |
| `PADDLEOCR_ANDROID_INTEGRATION.md` | Step-by-step guide to adding PaddleOCR via PaddleLite on Android |
| `evaluate_ocr.py` | Runnable test harness: generates 100 synthetic Indian ID cards, runs OCR, compares engines |
| `OCR_EVALUATION_README.md` | This file — how to run everything |

---

## Your current stack (already in the app)

- `Ocr.kt` — Google ML Kit Text Recognition v2, Latin script only, on-device via Play Services
- `Extractor.kt` — rule-based extraction for Aadhaar (Verhoeff checksum), PAN (O/0, I/1 fixes), Voter ID, DL, Passport MRZ, Bank passbook
- `build.gradle.kts` — already depends on `play-services-mlkit-text-recognition:19.0.1` + `play-services-mlkit-document-scanner:16.0.0`
- `TECH_STACK.md` notes Devanagari support is "later" (Phase 2)

---

## Step 1 — Install Python dependencies

```bash
cd C:\projects\ai_form_vault
pip install paddleocr opencv-python-headless pillow numpy tqdm
```

PaddleOCR will download its detection + recognition models on first run (~100 MB).

---

## Step 2 — Generate 100 test candidates (Indian ID cards)

```bash
python evaluate_ocr.py --generate-tests 100 --out test_set/
```

This creates `test_set/` with:
- 100 PNG images: Aadhaar (20), PAN (20), Voter ID (15), Driving Licence (15), Passport (10), Bank passbook (10)
- Languages: English (70), Hindi/Devanagari (30)
- Conditions: clean, skewed, low-light, folded, low-res, glare, motion-blur
- `ground_truth.csv` — exact text + extracted fields for every image

---

## Step 3 — Run PaddleOCR

```bash
python evaluate_ocr.py --engine paddleocr --input test_set/ --gt test_set/ground_truth.csv --out results_paddle.csv --lang multilingual
```

- `--lang multilingual` enables Hindi + other Indian regional languages
- Use `--lang en` for English-only (faster, smaller models)

Output: `results_paddle.csv` — per-image char/word/field accuracy, inference time, raw predictions.

---

## Step 4 — Run ML Kit baseline (simulated)

ML Kit is an Android Play Services API and **cannot run on a PC**. The harness includes a simulated baseline that models ML Kit's documented behavior (Latin-only — Devanagari/Hindi text is dropped):

```bash
python evaluate_ocr.py --engine mlkit --input test_set/ --gt test_set/ground_truth.csv --out results_mlkit.csv
```

> For real ML Kit numbers, run the evaluation inside your Android app on a device. The simulated baseline is useful for seeing the *regional-language gap* PaddleOCR fills.

---

## Step 5 — Compare and get the report

```bash
python evaluate_ocr.py --compare results_paddle.csv results_mlkit.csv --report comparison_report.md
```

This prints and writes a markdown report with:
- Overall character / word / field accuracy per engine
- Aadhaar checksum pass rate, PAN format pass rate
- Breakdown by document type, language, and condition
- Inference time and model size comparison
- Final recommendation

---

## Expected trade-offs (from the report)

| | Google ML Kit (current) | PaddleOCR (PaddleLite mobile) |
|---|---|---|
| Indian regional languages | ❌ Latin only | ✅ Hindi, Tamil, Telugu, Bengali, etc. |
| App size | 0 MB (already a dep) | +15–30 MB |
| Inference speed | Fast (~300–800 ms) | Slower (~800–2000 ms) |
| Integration | Already done | JNI/PaddleLite, custom wrapper |
| English ID accuracy | 85–92% | 90–95% |
| Hindi ID accuracy | Not supported | 85–90% |

**Recommendation:** Stay with ML Kit for the MVP (English-only, already integrated, privacy-first, tiny). Add PaddleOCR in Phase 2 only if you need Hindi/Devanagari or other regional languages, and accept the size/speed cost. A hybrid approach (ML Kit for English, PaddleOCR fallback for regional) gives the best of both.

---

## Troubleshooting

- **`paddleocr` not found:** `pip install paddleocr` — if it fails on Windows, try `pip install --upgrade pip` first, then reinstall.
- **Model download slow:** PaddleOCR downloads models from GitHub on first run; ensure internet access.
- **Devanagari text renders as boxes in test images:** The test generator tries `mangal.ttf` (Windows) / DejaVuSans (Linux). If your system lacks a Devanagari font, Hindi text may not render visibly in the PNG, but the ground truth CSV still contains it — PaddleOCR's multilingual model would still be tested on real device images.
- **No Android device:** `adb devices` shows none connected — that's expected in this environment. Real ML Kit numbers require an Android device/emulator running your app.
