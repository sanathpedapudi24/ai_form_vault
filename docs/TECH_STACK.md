# Tech Stack — decided 2026-10-11

Native Android MVP. Every hard requirement (Autofill Service, Keystore,
ML Kit, Material 3 dynamic color) is native, so there is no cross-platform
layer. Kotlin Multiplatform is the path if Phase 3 needs iOS.

| Concern | Choice |
|---|---|
| Language / UI | Kotlin, Jetpack Compose, Material 3 components |
| Visual style | Material 3 structure + soft animated aurora/glow gradient backgrounds (FeralUI-style), drawn with Compose `Canvas` radial gradients (works on all API levels; static when animations are off) |
| Capture | ML Kit Document Scanner (crop, edge detection, quality guidance) |
| OCR | ML Kit Text Recognition v2, on-device, unbundled via Play services (Latin script). Adaptive progressive pipeline: 3000px input, plain-first with quality gate (Aadhaar checksum / PAN pattern / date density), escalating to contrast → Otsu binarization → 90/180/270° rotation only when plain fails. Early exit cuts inference ~50–70% on clean docs. Devanagari later. |
| Extraction / classification | On-device, rule-based per Indian document type. No cloud AI. |
| Database | One AES-256-GCM encrypted JSON file (Keystore key) + per-page encrypted images. Room + SQLCipher only if vaults reach thousands of documents |
| Search | In-memory keyword + rule-based natural language (`Matching.kt`) |
| Document encryption | AES-256-GCM via `javax.crypto`, keys in Android Keystore |
| Access | No account. Biometric/PIN app lock via `androidx.biometric` |
| Autofill | Native `AutofillService` |
| Backend | None for MVP |
| Reminders | WorkManager daily job + local notifications |
| Backup | Passphrase-encrypted `.aivault` file (PBKDF2 + AES-256-GCM) via the system file picker |

## Deliberately deferred

- Accounts, backend, sync: Phase 2 (PRD §29). Supersedes FR-AUTH-01/02/04 for the MVP.
- Cloud AI: off. Revisit only with explicit per-document consent.
- Semantic/vector search: Phase 2.
- Browser extension, cross-platform: Phase 3.

## Gradient guardrails (from PRODUCT.md anti-references)

- Gradients are backgrounds only: never gradient text, never decorative glass panels.
- Not a purple/cyan palette.
- Animation respects reduced-motion and never gates content.
- Text on gradients must still meet WCAG AA contrast.
