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

## What leaves the device, and when

Nothing leaves the device unless a Gemini API key is configured. With one:

- **Scanning a document**: the downscaled document image (long edge capped
  at 1600px) and the on-device OCR text are sent to Google's
  `generateContent` API to extract structured fields. This is a single
  request per scan — Google's standard API terms apply to that request.
- **Search**: the query text and, for indexing, a text summary of each
  document (type, owner, non-sensitive field labels/values — **ID numbers
  are explicitly excluded** from what gets embedded) are sent to the
  embeddings endpoint.
- **Snap-to-Fill**: the photographed *blank form* (not your stored
  documents) and its OCR text are sent to detect fields. Your fact values
  used to fill the form are matched and inserted locally — they are not
  part of this request.

Without a key (`AppConfig.aiEnabled == false`), no network request is ever
made by the document-intelligence, search, or form-fill pipelines — the
regex parser, keyword search, and OCR-heuristic field detection run
entirely on-device.

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
