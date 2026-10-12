# Privacy & data handling

This app stores some of the most sensitive personal data that exists
(Aadhaar, PAN, passport numbers) with no account, so what's encrypted and
what ever leaves the device matters more than usual. This is the honest,
specific answer, with the code that backs each claim.

## At rest, on the device

- **Vault data** (documents, details, people, edits, settings) is one
  AES-256-GCM encrypted file, `vault.bin`. The key is generated in the
  Android Keystore (hardware-backed where the phone supports it) and never
  leaves it. See `Store.kt`.
- **Document page images** are re-encoded as JPEG and encrypted one by one
  with the same Keystore key (`img/<doc>_<page>.bin`). Nothing on disk is
  readable without the running app on this phone.
- **PIN**: only a salted PBKDF2 hash is stored. After 5 wrong tries an
  escalating cooldown (30s, doubling, capped at 5 min) stops brute force.
  See `Lock.kt`.
- **Android backup is off** (`allowBackup=false`, `no_backup.xml`): the
  Keystore key can't move to another phone, so a system backup copy would be
  unreadable anyway. Users back up with the app's own encrypted file instead.
- **Screenshots and screen recording are blocked** inside the app
  (`FLAG_SECURE`), which also hides it in the recent-apps preview.

## What leaves the device: nothing, unless you send it

There is no server, no account, no analytics and no cloud AI. Scanning (ML
Kit document scanner + text recognition), extraction, search, family
suggestions and Snap-to-Fill all run on the phone. The ML Kit models are
downloaded once by Google Play services; your images and text are not sent.

Things only leave when **you** do it: sharing a document page or a filled
form through the Android share sheet, or saving a backup file somewhere.
Shared copies are written to the app's cache and deleted the next time the
app starts.

## System-wide autofill: what other apps can see

Only when you pick AI Form & Vault as Android's autofill service **and** the
"Offer my details" switch is on. Then a field in another app gets a
suggestion only if it can be confidently matched (Android autofill hints, or
the field's id/hint/label), and nothing is filled until you tap the
suggestion. See `VaultAutofillService` in `Services.kt`.

**Offered:** name, date of birth, gender, father's, mother's and spouse's
names, mobile, email, address, PIN code, nationality, blood group, PAN.

**Never offered:** Aadhaar, passport, voter ID, driving licence and vehicle
numbers, roll numbers and expiry dates (`FactKey.shareable = false` in
`Model.kt`). Password fields are skipped.

Details from family members' documents are never offered: autofill only uses
your own profile.

## Backups

Backup files (`.aivault`) are a zip of the vault and images, encrypted with
AES-256-GCM using a key derived from your passphrase (PBKDF2-SHA256, 210,000
iterations, random salt). Without the passphrase nobody can open it,
including the developer. A forgotten passphrase can't be recovered.

## Deleting data

Deleting a document removes its record and its encrypted images
immediately. "Erase everything" (Profile) and "Forgot PIN" delete all app
files and the Keystore key, so nothing left behind can be decrypted.

## Regulatory note

This app has not been audited against India's Digital Personal Data
Protection Act or any other framework. Do that, plus a professional security
review, before handling real users' data at scale (PRD SEC-13).
