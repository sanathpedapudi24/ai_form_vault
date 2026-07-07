# Features

Legend: 🤖 = uses Gemini when configured, falls back to on-device logic
otherwise · 📴 = always on-device, no network involved.

## Home (Dashboard)

Greets you by name once it's known, surfaces pending relationship
confirmations, quick actions (Scan / Snap-to-Fill), live stats (documents,
people, connections), and the five most recent documents.

## Scan a document 🤖

`Add document` → camera (edge-detecting document scanner) or gallery →
`Scanning` (staged progress: reading → understanding → organizing) →
`Review`.

- **Reading**: ML Kit OCR on-device (Latin + Devanagari).
- **Understanding**: Gemini vision reads the image directly and returns
  document type, category, owner name, a privacy-conscious summary (no
  full ID numbers), extracted fields with confidence, and people mentioned
  with their relation to the owner. Falls back to a regex parser tuned for
  Aadhaar, PAN, Voter ID, Driving License, Vehicle RC, Passport, and
  education marksheets when there's no key or the request fails.
- **Review**: every field is editable before saving; editing marks a field
  "verified" (confidence 1.0, immune to being overwritten by future lower-
  confidence extractions of the same fact).

On save: the image is encrypted into the vault, a search embedding is
generated, and the identity engine writes facts + relationship suggestions.

## Vault

Browse all documents, filter by category (ID Proof, Education, Finance,
Medical, Travel, Family, Other) with live counts. Tap a document for full
detail: image, summary, all extracted fields, share, delete, or open as a
**Digital ID** card.

## Digital ID

A dark, wallet-style presentation of an identity document for showing
on-screen without handing over your phone or the physical card. Sensitive
numbers (Aadhaar, PAN, passport, voter ID, license) are masked to their
last 4 characters by default — tap to reveal.

## Search 🤖

Hybrid search: keyword matching always runs (document type, owner, category,
field labels/values); with a Gemini key, queries are also embedded and
ranked by cosine similarity against each document's embedding, so "when
does my insurance expire" can match without the word "insurance" appearing
verbatim. Results tagged **AI match** used the semantic path.

## Profile

Your identity facts (aggregated from every document you've scanned — the
highest-confidence, or user-verified, value wins per fact), a link into
Relationships, and settings (system autofill toggle, AI status).

## Relationships (confirm-first)

When a document names someone else (father, mother, spouse, guardian,
sibling, child), a relationship *suggestion* appears here with the
evidence ("Printed as father's name on PAN Card") — confirm or dismiss.
Nothing is treated as real identity data, and no family graph is drawn,
until you say yes. This directly addresses the roadmap's flagged risk:
*"This phase has real 'creepy app' risk if not handled with visible, simple
consent."*

## Snap-to-Fill 🤖

Photograph any blank form (not one of your own documents — someone else's
form you need to fill in). Gemini vision lists every field the form asks
for and maps it to a canonical fact key when possible; without a key, the
same detection runs off on-device OCR label heuristics. Each field is
matched against your verified facts, shown for review (tap to correct or
fill a gap manually), then you share the annotated result.

## System-wide autofill (Android only)

A native `AutofillService` (Kotlin) that other apps can query directly —
no need to open AI Form & Vault at all. See [PRIVACY.md](PRIVACY.md) for
exactly which facts are shared and how field-matching works.

## What works with zero configuration

Everything. No account, no login, no API key. Scanning, storage, search,
relationships (from the regex-detected father's-name field), Snap-to-Fill,
and system autofill all function on-device. A Gemini key raises extraction
accuracy and unlocks natural-language search and richer relationship
detection — it's an upgrade, not a requirement.
