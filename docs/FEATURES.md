# Features (v4.1, native Android)

Everything runs on the phone. No account, no server, no cloud AI. See
[PRIVACY.md](PRIVACY.md).

## First launch
A 3-page intro (what it does, privacy, filling forms), then creating a
4-digit PIN with optional fingerprint. Skippable, with a reminder on Home.

## App lock
PIN (salted hash) plus optional fingerprint. Re-locks whenever you leave the
app, except while you're in the scanner, share sheet or file picker. After 5
wrong PINs a cooldown starts (30s, doubling, max 5 min). "Forgot PIN" erases
the vault: there's no account to recover through.

## Home
Greeting, Scan / Fill a form / Import PDF, an app-lock nudge, a red alert
when details don't match across documents, the next family suggestion to
confirm, stats (documents, family, fields filled), documents expiring within
90 days, and recent documents.

## Scan a document
Camera with edge detection and cropping (up to 5 pages, gallery import
allowed) or a PDF (first 5 pages). Progress: reading → understanding →
organizing → **review**.

Recognised: Aadhaar (front and back, with checksum-validated numbers), PAN
(old and new layouts, fixing common misreads like O/0 and I/1), Voter ID,
driving licence, passport (front from the machine-readable lines; back page
for parents, spouse and address), vehicle RC, marksheets and bank passbooks
(account number, IFSC, bank, branch). Every page is also read a second time
with boosted contrast, for faint or grey print. Extracted: name, DOB,
gender, father's / mother's / spouse's names, address and PIN code, mobile,
email, blood group, nationality, ID numbers, roll number, expiry.

Review lists what this type of document usually has but wasn't found, and
"Send the scanned text" shares the raw text (after a privacy warning) so
misreads can be reported and fixed.

On review you can change the type, category and vault name, choose whose
document it is (you, a family member, or someone new), and fix, clear or
add any detail. Nothing is saved until you tap Save.

## Vault
All documents, filtered by category with counts. Document detail shows
swipeable pages (tap to zoom), details with numbers masked until you tap
"Show", an expiry badge, a note field, and Digital ID, Share and Delete.

## Digital ID
A wallet-style card with the name, the main ID number (masked, tap to
reveal), DOB, gender and expiry. Labelled as a reference, not an official ID.

## Search
Keywords across titles, types, owners, details and notes, plus plain
language: "sister's Aadhaar", "father's documents", "ID documents",
"what expires next year".

## Profile
Your details, built only from **your own** documents plus your edits, each
showing where it came from. When documents disagree (for example a DOB on
Aadhaar vs a marksheet) the card turns red, lists every value with its
source, and lets you mark the right one. Edits always win.

Settings: app lock, autofill, expiry reminders, encrypted backup and
restore, and erase everything.

## Family (confirm first)
When your own document names a father, mother or spouse who isn't known
yet, it's suggested with the evidence ("Printed as father's name on your PAN
card"). Nothing is linked until you confirm. Names are matched fuzzily
(reordered names, missing middle names, one-letter OCR slips). Family
members' documents stay with them and never feed your profile or autofill.

## Snap-to-Fill
Photograph a blank paper form. The app finds the labels, fills what it can
from your confirmed details, and shows every field for you to check.
Tick-box questions on one line (Male / Female / Other, Indian / NRI) get a
tick and a circle on the right option. Empty fields say which document to
scan for that detail. Lines about other people (nominee, witness, school)
are never filled. Values
are written onto the image, which you can zoom and share or print.
Corrections are saved back to your profile.

## System-wide autofill
A native Android autofill service. Once you pick it in Android settings,
other apps and websites get a "Fill N fields from AI Form & Vault"
suggestion for fields it can confidently match, including dropdowns. ID numbers other than PAN
are never offered.

## Expiry reminders
A local notification 90, 30 and 7 days before a document expires, and on
the day.

## Backup & restore
Export one `.aivault` file encrypted with your passphrase, saved wherever
you like. Restore merges it into the current vault.

## Not built yet
- Play Billing / paywall (needs a Play Console listing and products).
- DigiLocker import (needs government partner access).
- Cloud sync and accounts (PRD Phase 2).
- Hindi/Devanagari text reading (only English text is read for now).
- Semantic (embedding-based) search (Phase 2); search is keyword and
  rule-based today.
