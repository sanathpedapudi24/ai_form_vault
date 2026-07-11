# AI Form & Vault

**Store once. Understand forever. Reuse everywhere.**

A Flutter app that turns a photo of any Indian identity document — Aadhaar,
PAN, passport, marksheets — into structured, private knowledge: extracted
facts, a confirmed family/identity graph, natural-language search, and
one-tap form filling anywhere on the phone.

No login is required. Nothing you scan ever leaves the device — not to a
server, not to an AI API. Everything lives encrypted on the device, and
every feature runs entirely on-device by design (see
[docs/PRIVACY.md](docs/PRIVACY.md)).

## What it does

- **Scan** — camera or gallery → on-device OCR → a regex-based parser
  tuned for Indian documents extracts fields as clean, labeled data.
- **Understand** — extracted fields become canonical *facts* on a person
  (name, DOB, PAN, etc.), and people mentioned on a document (father,
  spouse, guardian) become *relationship suggestions* — nothing is assumed
  without your confirmation.
- **Search** — ask in plain English ("find my passport", "when does my ID
  expire") and get keyword + natural-language-aware results across your
  vault, entirely on-device.
- **Snap-to-Fill** — photograph any blank form; the vault detects its
  fields and fills them from your verified facts before you share it.
- **System-wide autofill** — register the app as an Android AutofillService
  so other apps can request your saved details directly.
- **App lock** — 4-digit PIN with optional biometric unlock protects the
  vault itself.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the layers
separate, and [docs/PRIVACY.md](docs/PRIVACY.md) for exactly what the
on-device-only guarantee means in code.

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (this
   project targets the `stable` channel, SDK `^3.10.4`).
2. `flutter pub get`
3. `flutter run`

No API key setup needed — cloud AI is permanently disabled (see
[docs/PRIVACY.md](docs/PRIVACY.md)).

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
image store · Google ML Kit (on-device OCR) · go_router · Kotlin
`AutofillService` · `local_auth` (biometric app lock). A Gemini integration
exists in the codebase but is deliberately disabled — see
[docs/PRIVACY.md](docs/PRIVACY.md).
