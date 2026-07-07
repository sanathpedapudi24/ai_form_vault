# AI Form & Vault

**Store once. Understand forever. Reuse everywhere.**

A Flutter app that turns a photo of any Indian identity document — Aadhaar,
PAN, passport, marksheets — into structured, private knowledge: extracted
facts, a confirmed family/identity graph, natural-language search, and
one-tap form filling anywhere on the phone.

No login is required. Everything lives encrypted on the device.

## What it does

- **Scan** — camera or gallery → on-device OCR → Gemini vision reads the
  document and extracts every field as clean, labeled data.
- **Understand** — extracted fields become canonical *facts* on a person
  (name, DOB, PAN, etc.), and people mentioned on a document (father,
  spouse, guardian) become *relationship suggestions* — nothing is assumed
  without your confirmation.
- **Search** — ask in plain English ("find my passport", "when does my ID
  expire") and get semantic + keyword results across your vault.
- **Snap-to-Fill** — photograph any blank form; the vault detects its
  fields and fills them from your verified facts before you share it.
- **System-wide autofill** — register the app as an Android AutofillService
  so other apps can request your saved details directly.

Every AI feature degrades gracefully: without a Gemini key, the app runs
entirely on-device (ML Kit OCR + a regex-based Indian-document parser,
keyword search, manual relationship entry). See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the layers separate.

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (this
   project targets the `stable` channel, SDK `^3.10.4`).
2. `flutter pub get`
3. (Optional, recommended) add a Gemini API key — see
   [docs/SETUP.md](docs/SETUP.md).
4. `flutter run`

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — system design, data flow,
  the four-layer model, why each library was chosen.
- [docs/SETUP.md](docs/SETUP.md) — API keys, running on a device/emulator,
  enabling system autofill.
- [docs/FEATURES.md](docs/FEATURES.md) — every screen and feature, what's
  AI-powered vs. on-device.
- [docs/PRIVACY.md](docs/PRIVACY.md) — what's encrypted, what leaves the
  device and when, what system autofill can and can't see.
- [docs/prd.md](docs/prd.md), [docs/trd.md](docs/trd.md),
  [docs/design.md](docs/design.md) — original product/technical/design specs.

## Tech stack

Flutter + Riverpod · SQLCipher (encrypted SQLite) · AES-256-GCM encrypted
image store · Google ML Kit (on-device OCR) · Gemini 2.5 Flash (vision
extraction + embeddings) · go_router · Kotlin `AutofillService`.
