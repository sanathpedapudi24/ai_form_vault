# Privacy & data handling

This app stores some of the most sensitive personal data that exists
(Aadhaar, PAN, passport numbers) with no login, so what's encrypted and
what ever leaves the device matters more than usual. This document is the
honest, specific answer.

## At rest, on the device

- **Database** (documents, fields, people, facts, relationships, settings):
  a SQLCipher-encrypted SQLite file. The passphrase is a random 256-bit
  value generated on first launch and stored in the platform Keystore
  (Android) / Keychain (iOS) via `flutter_secure_storage` — it is never
  written to app-readable storage or backed up in plaintext.
- **Document images**: encrypted independently with AES-256-GCM
  (authenticated encryption — tampering is detected, not just prevented)
  using a separate key, also Keystore/Keychain-held. Files on disk are
  ciphertext; nothing decrypts them without the running app.
- **Facts shared with system autofill**: stored in
  `EncryptedSharedPreferences` (AndroidX Security, AES-256), a distinct
  encrypted store from the main vault, containing only the fields you've
  opted to share (see below).

## What leaves the device: nothing

Document images and OCR text never leave the device. This isn't a default
that happens to be true because no API key is configured — `AppConfig.aiEnabled`
is a hardcoded `false` (see [app_config.dart](../lib/core/config/app_config.dart)),
and every network-touching code path (document scanning, search embeddings,
Snap-to-Fill field detection) is gated on that one constant. Pasting a
Gemini key into `api_keys.dart` does **not** turn any of this back on — the
Gemini client code stays in the repo (it's a real, working integration),
but it's wired to a switch that's deliberately nailed shut.

Document scanning, search, and Snap-to-Fill field detection all run
entirely on-device: a regex-based parser tuned for Indian ID documents,
keyword + light natural-language query matching, and OCR-heuristic field
detection. The tradeoff is a lower extraction-accuracy ceiling than a cloud
vision model would give — that tradeoff was made deliberately in exchange
for the guarantee above, not as a placeholder.

If that decision is ever revisited, it should be a deliberate code change
(flipping `AppConfig.aiEnabled` back to reading `ApiKeys.gemini`), not
something that happens by accident.

## System-wide autofill: what other apps can see

When you enable system autofill, a fixed allowlist of fact keys is copied
into the native `EncryptedSharedPreferences` store — see
`AutofillBridge._sharedKeys` in
[autofill_bridge.dart](../lib/core/services/autofill_bridge.dart):

**Shared:** full name, date of birth, gender, father's/mother's name,
phone, email, address, PIN code, PAN, blood group, nationality.

**Never shared:** Aadhaar number, passport number, voter ID, driving
license, vehicle registration — anything in `FactKeys.sensitive`.

The native `VaultAutofillService` only fills a field in another app if it
can confidently match that field to one of the shared keys (via Android's
own `autofillHints` when the target app sets them, or heuristics over the
field's visible label otherwise). It never sends your data anywhere except
directly into the focused field on your own device — autofill is a local
OS mechanism, not a network call.

Turning the toggle off immediately clears the shared-facts store
(`AutofillBridge.clearAutofillData()`); the OS-level "default autofill
service" selection is a separate setting you control from Android's own
Settings app.

## Deleting data

Deleting a document removes its database row and both its encrypted image
files immediately (`DocumentsNotifier.remove` → `ImageVault.delete`).
There is currently no cloud backup or sync (Phase 5 in the roadmap) — this
is the one copy, and deleting it is final.

## Regulatory note

This app is designed for a no-auth, on-device-first MVP. It has not been
audited against India's Digital Personal Data Protection Act or any other
regulatory framework — do that work, and get a professional security
review, before handling real user data beyond your own testing.
