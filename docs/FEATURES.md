# Features

Everything below runs entirely on-device. No document image or extracted
text is ever sent to a network API — see [PRIVACY.md](PRIVACY.md) for the
code-level guarantee behind that claim.

## App lock

4-digit PIN (salted, hashed, Keystore-held) with optional biometric unlock
on top. Required on first run (skippable, with a nag to set it up later
from Profile), re-locks whenever the app is backgrounded. "Forgot PIN"
wipes the local vault as a last resort — there's no cloud account to
recover through otherwise.

## Home (Dashboard)

Greets you by name once it's known, surfaces pending relationship
confirmations, quick actions (Scan / Snap-to-Fill), live stats (documents,
people, connections), and the five most recent documents.

## Scan a document

`Add document` → camera (edge-detecting document scanner) or gallery →
`Scanning` (staged progress: reading → understanding → organizing) →
`Review`.

- **Reading**: ML Kit OCR on-device (Latin + Devanagari).
- **Understanding**: a regex parser tuned for Aadhaar, PAN, Voter ID,
  Driving License, Vehicle RC, Passport, and education marksheets extracts
  fields, classifies the document type, and infers the owner.
- **Review**: every field is editable before saving; editing marks a field
  "verified" (confidence 1.0, immune to being overwritten by future lower-
  confidence extractions of the same fact).

On save: the image is encrypted into the vault and the identity engine
writes facts + relationship suggestions.

## Vault

Browse all documents, filter by category (ID Proof, Education, Finance,
Medical, Travel, Family, Other) with live counts. Tap a document for full
detail: image (tap to zoom full-screen), summary, all extracted fields,
share, delete, or open as a **Digital ID** card.

## Digital ID

A dark, wallet-style presentation of an identity document for showing
on-screen without handing over your phone or the physical card. Sensitive
numbers (Aadhaar, PAN, passport, voter ID, license) are masked to their
last 4 characters by default — tap to reveal.

## Search

Hybrid on-device search: keyword matching (document type, owner, category,
field labels/values) plus lightweight natural-language handling — question
phrasing ("find my", "when does X expire") is stripped, category synonyms
("ID" → identity documents) are recognized, and expiry-related queries
reason about actual expiry dates on your documents.

## Profile

Your identity facts (aggregated from every document you've scanned — the
highest-confidence, or user-verified, value wins per fact), a link into
Relationships, and settings (system autofill toggle, app lock).

## Relationships (confirm-first)

When a document names someone else (father, mother, spouse, guardian,
sibling, child), a relationship *suggestion* appears here with the
evidence ("Printed as father's name on PAN Card") — confirm or dismiss.
Nothing is treated as real identity data, and no family graph is drawn,
until you say yes. Name matching is fuzzy (handles OCR misspellings,
reordered names, missing middle names) so the same person scanned on
different documents doesn't get duplicated.

## Snap-to-Fill

Photograph any blank form (not one of your own documents — someone else's
form you need to fill in). On-device OCR label heuristics detect what each
field is asking for and map it to a canonical fact key when possible. Each
field is matched against your verified facts, shown for review (tap to
correct or fill a gap manually — corrections are saved back to your
profile for next time), then the values are rendered onto the form image
before you share it.

## System-wide autofill (Android only)

A native `AutofillService` (Kotlin) that other apps can query directly —
no need to open AI Form & Vault at all. See [PRIVACY.md](PRIVACY.md) for
exactly which facts are shared and how field-matching works.

## What works with zero configuration

Everything. No account, no login, no API key, no setup. Scanning, storage,
search, relationships, Snap-to-Fill, and system autofill all function
entirely on-device, permanently — this isn't a fallback mode, it's the
only mode.
