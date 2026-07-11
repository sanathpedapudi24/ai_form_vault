# Architecture

> **Cloud AI is permanently disabled.** The Gemini integration described
> below (`GeminiClient`, `DocumentIntelligence._analyzeWithGemini`,
> `EmbeddingService`, `FormFillService`'s vision path) is real, working
> code, but it's gated behind `AppConfig.aiEnabled`, which is a hardcoded
> `false` — not a check on whether an API key is present. No document
> image or OCR text is ever sent anywhere. See [PRIVACY.md](PRIVACY.md).
> The rest of this document describes the full architecture including the
> disabled Gemini path, since the code is still there and still the
> designed fallback target if that decision is ever revisited.

## The four-layer model

The roadmap's core mental model, and the one this codebase is built around:

```
Input Sources          AI Processing           Knowledge Layer         Application Layer
─────────────          ──────────────           ───────────────         ─────────────────
Camera / gallery   →   OCR (ML Kit)         →   Documents (SQLCipher)  → Vault browsing
                       ↓                        Facts (per person)     → Search
                       Gemini vision            Relationships (graph)  → Snap-to-Fill
                       (or regex fallback)       Embeddings             → System autofill
```

Each layer is replaceable without touching the others — swapping ML Kit for
Tesseract, or Gemini for another model, shouldn't require changing storage
or UI code. Concretely:

- **Input**: `image_picker`, `google_mlkit_document_scanner` — just produce
  a JPEG path.
- **AI processing**: `OcrService` (on-device text) → `DocumentIntelligence`
  (classification + extraction, AI or regex) → `IdentityEngine` (turns
  extraction into facts + relationship suggestions).
- **Knowledge**: `DocumentRepository`, `PersonRepository` over an encrypted
  SQLCipher database (`AppDatabase`), plus an AES-256-GCM encrypted image
  store (`ImageVault`).
- **Application**: Riverpod providers (`lib/core/providers/`) expose the
  knowledge layer to screens; screens never touch the database directly.

## Directory layout

```
lib/
  core/
    config/        API keys (gitignored) + tunables (models, thresholds)
    models/        Plain Dart data classes (Document, Person, Fact, Relationship)
    db/            SQLCipher schema + legacy-data migration
    services/      OCR, Gemini client, document intelligence, identity engine,
                   embeddings, search, form-fill, image encryption/prep,
                   native autofill bridge
    repositories/  CRUD over the database — the only code that runs SQL
    providers/     Riverpod glue between services/repositories and UI
    router/        go_router route table
    theme/         Colors, type, motion tokens
  features/        One folder per screen (dashboard, vault, capture, scanning,
                   review, document, search, profile, relationships,
                   snap_to_fill, virtual_id, shell)
  shared/widgets/  Reusable UI (buttons, cards, badges, empty states, motion)

android/app/src/main/kotlin/.../
  MainActivity.kt          MethodChannel bridge (Dart ↔ native)
  AutofillDataStore.kt     EncryptedSharedPreferences for shared facts
  VaultAutofillService.kt  Android AutofillService implementation
```

## Data flow: scanning a document

1. `DocumentCaptureScreen` gets an image path (camera scanner or gallery).
2. `CaptureNotifier.process()` runs the pipeline:
   - `OcrService` extracts raw text on-device (ML Kit, Latin + Devanagari).
   - `ImagePrep` downscales the image once (isolate-based, `compute()`) —
     the same bytes go to Gemini and into permanent storage.
   - `DocumentIntelligence.analyze()` tries Gemini vision first (structured
     JSON: category, type, owner, fields, people mentioned, confidence).
     On any `GeminiException` (no key, offline, quota, blocked content) it
     falls back to `DocumentParser` (regex over the OCR text) — the same
     fallback used when no API key is configured at all.
   - `IdentityEngine.resolveOwner()` matches the extracted name against
     existing people (or creates a new one).
3. A draft `DocumentModel` is shown on `ReviewScreen` — the user can edit
   any field, the name, or the category before anything is saved.
4. On save: the image is encrypted into `ImageVault`, the document row is
   written via `DocumentRepository`, an embedding is generated for search
   (`EmbeddingService`, no-op without a key), and `IdentityEngine.ingest()`
   writes canonical facts + relationship *suggestions* (status: pending)
   for anyone else named on the document.
5. Relationship suggestions surface on `RelationshipsScreen` for the user
   to confirm or reject — nothing is treated as true identity data until
   confirmed.

## Why these libraries

| Concern | Choice | Why |
|---|---|---|
| State | `flutter_riverpod` | Already in the codebase; testable providers, no BuildContext coupling. |
| Routing | `go_router` | Declarative, `StatefulShellRoute` gives the bottom-nav + full-screen-flow split for free. |
| Local DB | `sqflite_sqlcipher` | Drop-in SQLite API with transparent AES encryption — no separate encrypt/decrypt step in app code. |
| DB key storage | `flutter_secure_storage` | Android Keystore / iOS Keychain; the key never touches app-readable storage. |
| Image encryption | `cryptography` (AES-256-GCM) | Documents are the most sensitive asset in the app; images get their own authenticated encryption, independent of the DB. |
| On-device OCR | `google_mlkit_text_recognition` | Free, fast, offline, and already used by the original prototype; Latin + Devanagari scripts covers the common Indian document set. |
| AI extraction | Gemini REST API (`http`) | One key covers both vision extraction *and* embeddings (`gemini-embedding-001`), which is why it's the default over Claude/OpenAI. |
| Semantic search | Cosine similarity over stored `Float32List` embeddings | No hosted vector DB needed at this scale (roadmap's own Phase 4 guidance: "you may not need a hosted vector database"). |

## Extending

- **New document type**: add extraction hints in
  `DocumentIntelligence._analyzeWithGemini`'s prompt and, for the offline
  fallback, a parser method in `DocumentParser` plus a case in
  `DocumentIntelligence.semanticKeyForLabel`.
- **New fact type**: add a key + label to `FactKeys` in
  `lib/core/models/document_model.dart` — it automatically flows through
  facts, the review screen, and Snap-to-Fill matching.
- **New AI provider**: replace `GeminiClient` behind the same
  `generateJson`/`embed` interface; nothing above `DocumentIntelligence`/
  `EmbeddingService` needs to change.
