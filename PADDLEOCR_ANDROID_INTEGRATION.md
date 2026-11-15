# Integrating PaddleOCR into AI Form & Vault (Android)

**Target:** Add PaddleOCR as a regional-language OCR option alongside Google ML Kit.  
**Status:** Phase 2 (per your PRD/TECH_STACK: multilingual support is deferred).

---

## Why PaddleOCR is not "drop-in" on Android

PaddleOCR is a **Python** framework (PaddlePaddle). Android runs Kotlin/Java. To use it on-device you must:

1. Train/export a PaddleOCR model → inference model (`__model__`, `__param__`)
2. Convert it to **PaddleLite** format (`.nb` / `.ptl`) — the mobile-optimized runtime
3. Add the PaddleLite Android AAR to your app
4. Write JNI/C++ or use the PaddleLite Java/Kotlin API to run inference
5. Preprocess (resize, normalize) and postprocess (CTC decode, NMS) in Kotlin/C++

There is **no official `com.google.android.gms:play-services-paddleocr`**. You self-host everything.

---

## Integration Options

### Option 1: PaddleLite AAR (recommended, fully on-device)

| Step | Action |
|---|---|
| 1 | Download PaddleLite Android AAR from [PaddleLite releases](https://github.com/PaddlePaddle/PaddleLite/releases) |
| 2 | Export your PP-OCR detection + recognition models with `tools/export_model.py` |
| 3 | Convert to PaddleLite format: `lite/tools/convert_model.py` |
| 4 | Add `.nb` model files to `app/src/main/assets/models/` |
| 5 | Add PaddleLite AAR as a `flatDir` dependency in `app/build.gradle.kts` |
| 6 | Write Kotlin wrapper that loads models, preprocesses bitmaps, runs inference |
| 7 | Feed results into your existing `Extractor.kt` regexes |

**Estimated app size impact:** +15–30 MB (PaddleLite runtime + English + Hindi models)

### Option 2: PaddleOCR server (NOT recommended for your privacy model)

Run PaddleOCR on a cloud GPU and call it from the app via HTTP.  
**Violates your privacy-first design** (document bytes leave the device) and adds latency/cost. Only consider if Phase 3 adds cloud sync with explicit consent.

### Option 3: Hybrid ML Kit + PaddleOCR (best balance)

```
English document   → ML Kit (fast, 0 MB extra, already integrated)
Hindi / regional   → PaddleOCR via PaddleLite (accurate on Devanagari)
Confidence < 0.7   → run both, pick higher-confidence result
```

This keeps the common case (English PAN/Aadhaar) lightning-fast while adding regional-language coverage where needed.

---

## Step-by-Step: Adding PaddleLite to `app/build.gradle.kts`

```kotlin
android {
    // ...
    sourceSets {
        main {
            assets {
                srcDirs("src/main/assets")
            }
            jniLibs {
                srcDirs("libs/paddlelite")  // .so files from PaddleLite AAR
            }
        }
    }
}

dependencies {
    // Existing
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")

    // PaddleLite (add the AAR you downloaded)
    implementation(files("libs/paddlelite-java.aar"))
    implementation(files("libs/paddlelite.aar"))
}
```

### models directory
```
app/src/main/assets/models/
├── en_ppocr_mobile_v2.0_det.nb        # English detection (~4 MB)
├── en_ppocr_mobile_v2.0_rec.nb        # English recognition (~5 MB)
├── ch_ppocr_mobile_v2.0_det.nb        # Detection (shared, ~4 MB)
└── ch_ppocr_mobile_v2.0_rec.nb        # Recognition multilingual (~12 MB, incl. Hindi)
```

> Tip: The detection model is shared across languages. Only the recognition model changes per language. English + Hindi ≈ 15–20 MB total.

---

## Kotlin Wrapper Sketch

```kotlin
package com.aiformvault

import android.content.Context
import android.graphics.Bitmap
import com.baidu.paddle.lite.MobileConfig
import com.baidu.paddle.lite.PaddlePredictor
import java.io.InputStream

object PaddleOcr {
    private var predictor: PaddlePredictor? = null

    fun init(ctx: Context) {
        // Load detection + recognition models from assets
        val detModel = ctx.assets.open("models/det.nb").readBytes()
        val recModel = ctx.assets.open("models/rec.nb").readBytes()
        // ... build PaddleLite predictors ...
    }

    fun recognize(bmp: Bitmap): String {
        // 1. Preprocess: letterbox resize to model input size, normalize
        // 2. Run detection (DB) → text boxes
        // 3. For each box: crop, run recognition (CRNN/RSViT) → text + confidence
        // 4. Return concatenated text sorted by reading order
        return ""
    }
}
```

---

## Where to Hook Into Your Existing Code

### `Ocr.kt` — add a second recognizer

```kotlin
object Ocr {
    private val mlKitRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    private val paddleOcr by lazy {
        PaddleOcr.getInstance()  // initialized in Application.onCreate
    }

    fun text(ctx: Context, pages: List<Uri>, preferLanguage: String = "en"): String =
        pages.joinToString("\n") { uri ->
            Store.decodeScaled(ctx, uri, 2400)?.let { bmp ->
                when (preferLanguage) {
                    "en" -> bestText(bmp)                 // existing ML Kit path
                    "hi", "ta", "te", "bn", "mr", "gu", "pa" -> paddleOcr.recognize(bmp)
                    else -> {
                        // Hybrid: try ML Kit first, fall back to PaddleOCR if result is thin
                        val ml = bestText(bmp)
                        if (ml.count(Char::isLetterOrDigit) < 5) paddleOcr.recognize(bmp) else ml
                    }
                }
            }.orEmpty()
        }
}
```

### `Extractor.kt` — no changes needed

Your regex-based extractor works on raw text regardless of engine. Just ensure the OCR output preserves Latin characters for PAN/Aadhaar digits. PaddleOCR returns Unicode, so Devanagari names will come through as-is (good for display, not needed for regex extraction since your extractor strips non-ASCII for labels).

---

## Models to Download (PP-OCRv4 Mobile)

| Model | Purpose | Size (approx.) |
|---|---|---|
| `en_ppocr_mobile_v2.0_det` | English text detection | 4.2 MB |
| `en_ppocr_mobile_v2.0_rec` | English recognition | 5.1 MB |
| `ch_ppocr_mobile_v2.0_rec` | Multilingual recognition (incl. Hindi) | 12–15 MB |
| `ch_ppocr_mobile_v2.0_det` | Shared detection (alternative) | 4.2 MB |

Source: PaddleOCR model zoo — `https://github.com/PaddlePaddle/PaddleOCR/blob/release/2.8/docs/models/Mobile/README.md`

---

## Performance Expectations (Android, mid-range CPU)

| Engine | Inference / page | App size | Accuracy (English ID) | Accuracy (Hindi ID) |
|---|---|---|---|---|
| ML Kit (current) | ~300–800 ms | 0 MB | 85–92% | ❌ Not supported |
| PaddleOCR (PaddleLite) | ~800–2000 ms | +15–30 MB | 90–95% | 85–90% |

---

## Decision Checklist

Before adding PaddleOCR, confirm:

- [ ] You need Hindi/Devanagari or other Indian regional language OCR now (not Phase 2)
- [ ] You can absorb +15–30 MB APK size
- [ ] You can maintain PaddleLite model versions yourself
- [ ] You accept ~2–3× slower OCR on the regional-language path

If any answer is "no," stay with ML Kit and apply the preprocessing improvements below instead.

---

## Quick Wins Without Switching Engines

If you stay with ML Kit (recommended for MVP), improve accuracy in `Ocr.kt`:

1. **Higher resolution:** `Store.decodeScaled(ctx, uri, 3000)` instead of 2400
2. **Multi-angle:** Rotate bitmap 90°/180°/270° and OCR each; keep the result with most alphanumerics
3. **Adaptive binarization:** Convert to grayscale + Otsu threshold before OCR (helps laminated PAN glare)
4. **Contrast boost already present:** Keep the `highContrast` two-pass — it helps faint Aadhaar print
5. **Image padding:** Add white border around the card before OCR (helps edge detection)

---

## If You Decide to Proceed with PaddleOCR

1. Install Python deps: `pip install paddleocr`
2. Run the evaluation harness: `python evaluate_ocr.py --generate-tests 100 --out test_set/`
3. Run PaddleOCR: `python evaluate_ocr.py --engine paddleocr --input test_set/ --gt test_set/ground_truth.csv --out results_paddle.csv`
4. Compare with ML Kit baseline and review `comparison_report.md`
5. If accuracy gain justifies the size/speed cost, begin PaddleLite Android integration
