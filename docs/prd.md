# AI Form & Vault — Complete Product Requirements Document

Personal AI Vault • Intelligent Document Understanding • Smart Search • Snap-to-Fill • Autofill Everywhere

Version 1.1 | 25 August 2026

## 1. Executive Summary

- AI Form & Vault is a privacy-first personal information and document intelligence platform combining a secure document vault, OCR, AI document understanding, automatic organization, structured profile generation, identity/relationship mapping, natural-language search, paper-form Snap-to-Fill, and Android Autofill Service.
- The core principle is: **Store once. Understand forever. Reuse everywhere.** A document uploaded once becomes a reusable source of confirmed information while remaining under the user's control.
- The product starts as an Android MVP and can evolve into cross-platform, browser, business/enterprise and agentic application-assistance products.

## 2. Product Vision

- Build a trusted Personal AI Vault that understands a user's documents and structured information, protects them with strong encryption, finds information instantly, and safely reuses confirmed information wherever forms or applications require it.
- The product is not merely an OCR scanner or autofill utility. Its differentiating loop is: Document → OCR → AI Understanding → Structured Knowledge → Search/Profile → Form Automation.
- **Existing tools each solve one slice of this problem, and none of them close the loop.** DigiLocker stores government documents but doesn't understand or reuse their contents. Password managers like 1Password autofill known digital forms but can't touch a photographed paper form, a scanned certificate, or anything requiring document understanding. OCR/scanner apps like CamScanner or Adobe Scan extract text but produce no structured, reusable knowledge — every scan is a dead end. AI Form & Vault is the first product to close the loop across all three: a single confirmed knowledge base that feeds both digital autofill and paper Snap-to-Fill.
- This matters most in contexts — like Indian college admissions, scholarships, government services, and family paperwork — where paper forms and digital forms are used interchangeably and nobody currently bridges them.

## 3. Problem Statement

- People repeatedly enter the same personal information into college applications, government services, banking forms, insurance forms, job applications, registrations, websites and mobile apps.
- Important documents are also scattered across galleries, downloads, email, cloud drives and physical files. Existing tools commonly solve only one part: storage, OCR, password management or autofill.
- **The specific failure mode competitors leave open:** a student photographs their marksheet into Google Drive (stored, not understood), uses 1Password for their email login (autofilled, but only digital), and still hand-copies the same date of birth and address onto a paper scholarship form for the fifth time this month (neither stored nor reused). No single product currently owns that whole chain.
- The product must reduce repetitive entry while improving organization, retrieval, accuracy and privacy.

## 4. Goals

- Reduce repetitive form entry.
- Create one organized repository for important documents.
- Automatically extract and structure useful information.
- Automatically generate useful document names and categories.
- Enable search by name, document type, keyword, date and natural-language intent.
- Build a profile from confirmed information instead of requiring a long onboarding form.
- Represent people and relationships without incorrectly assigning another person's information to the owner.
- Provide Snap-to-Fill for photographed, scanned and PDF forms.
- Provide Android Autofill for supported apps and websites.
- Make encryption, consent and user control foundational.

## 5. Non-Goals for MVP

- Fully autonomous submission of government, banking or legal applications.
- Bypassing CAPTCHA, anti-bot controls, website security or access restrictions.
- Using Accessibility Service as the primary autofill mechanism.
- Guaranteeing compatibility with every website or Android application.
- Automatic sharing of sensitive documents with support staff.
- Making legal, financial or identity-verification decisions for users.

## 6. Target Users

- **Students:** certificates, IDs, resumes, scholarships, admissions and jobs — the heaviest repeat-entry burden of any segment, and the group most likely to hit both paper and digital forms in the same week.
- **Citizens:** identity documents, government services and applications.
- **Professionals:** education, employment, travel and compliance documents.
- **Families:** documents for multiple people with explicit relationship confirmation.
- **Future MSME users:** employee onboarding, KYC, vendor registration and compliance.

## 7. Core Value Proposition

- **The only product that bridges paper and digital form-filling from one confirmed knowledge base** — photograph a paper scholarship form and a browser signup field, and both pull from the same verified profile.
- Information extracted once can be reused repeatedly, across both contexts.
- AI names and organizes documents automatically.
- Search by meaning instead of filenames.
- Android Autofill can reuse confirmed information where supported.
- Privacy-first architecture aims to prevent routine platform-operator access to plaintext user documents.

## 8. Competitive Landscape

| Product | What it does well | Where the gap is |
|---|---|---|
| **DigiLocker** | Official, government-trusted storage for Indian identity/education documents; strong legal standing | No document understanding, no structured reuse, no autofill of any kind — it's a filing cabinet, not a knowledge base |
| **1Password / Google Password Manager** | Polished, reliable autofill for known digital fields; strong encryption UX | Digital-only — cannot read a photographed paper form, cannot extract or structure document content, no concept of a "document" at all |
| **CamScanner / Adobe Scan** | Fast, high-quality OCR and scanning; large user base | Output is a flat image/PDF or raw text — nothing structured, nothing reusable, no profile, no autofill |
| **Google Lens / ML Kit (raw)** | Solid on-device text recognition primitive | Not a product — no vault, no confidence/provenance model, no relationship graph, no autofill integration |
| **Generic form-filling browser extensions** | Convenient for repeat web forms | Web-only, no document vault, no paper-form support, weak on Indian-specific document types (Aadhaar, marksheets, etc.) |
| **AI Form & Vault** | Understands documents, builds a confirmed profile with provenance, and reuses it across *both* paper (Snap-to-Fill) and digital (Autofill) forms | Newer entrant, must earn trust DigiLocker already has, and must prove privacy claims with real cryptographic architecture, not marketing |

- **Read on this table honestly:** the moat is the *combination*, not any single feature. Each competitor could theoretically add the missing piece — DigiLocker could add extraction, 1Password could add OCR — which is why this needs to be tracked as a real competitive risk (see Section 34) rather than assumed to be durable.

## 9. Core Product Modules

- Authentication and account security.
- Personal profile and provenance.
- Secure document vault.
- OCR and document ingestion.
- AI document classification and extraction.
- Automatic naming and categorization.
- Profile enrichment and conflict resolution.
- Identity and relationship graph.
- Smart search.
- Snap-to-Fill.
- Android Autofill Service.
- Encryption, key management, consent and audit.
- Backup/recovery, settings and billing.
- Future browser extension, APIs and enterprise workflows.

## 10. Functional Requirements — Authentication

- FR-AUTH-01: Secure account creation and sign-in.
- FR-AUTH-02: Secure sign-out and session expiry.
- FR-AUTH-03: Biometric/PIN protection for local vault access where supported.
- FR-AUTH-04: Secure recovery without routine plaintext access by support staff.
- FR-AUTH-05: Re-authentication for sensitive actions.

## 11. Functional Requirements — Profile

- FR-PROF-01: Structured fields for name, DOB, phone, email, addresses, education, employment and other configured data.
- FR-PROF-02: Values can originate from manual entry or confirmed document extraction.
- FR-PROF-03: Every extracted value keeps provenance: source document, confidence, timestamp and confirmation status.
- FR-PROF-04: Conflicting values are shown as conflicts rather than silently overwritten.
- FR-PROF-05: User can approve, edit, reject and delete profile values.

## 12. Functional Requirements — Vault

- FR-VAULT-01: Upload images, PDFs and supported files.
- FR-VAULT-02: Capture documents using camera.
- FR-VAULT-03: Import from gallery/files.
- FR-VAULT-04: Future integration may support DigiLocker where legally and technically appropriate.
- FR-VAULT-05: Generate thumbnails and metadata.
- FR-VAULT-06: Classify documents such as identity, education, finance and insurance.
- FR-VAULT-07: Suggest names such as Aadhaar Card — User Name.
- FR-VAULT-08: Rename, categorize, archive and delete documents.
- FR-VAULT-09: Apply secure deletion/retention policy.
- FR-VAULT-10: Show processing status and last processed time.

## 13. Functional Requirements — OCR & AI Understanding

- FR-OCR-01: OCR supported images and document pages.
- FR-OCR-02: Evaluate Google ML Kit, Tesseract and cloud document services based on accuracy, cost and privacy.
- FR-OCR-03: Treat OCR output as untrusted raw text until validated.
- FR-OCR-04: Classify document type.
- FR-OCR-05: Extract configured entities and fields.
- FR-OCR-06: Suggest document name and category.
- FR-OCR-07: Produce confidence indicators where supported.
- FR-OCR-08: Do not automatically assign information about another person to the owner.
- FR-OCR-09: Mask sensitive fields in normal UI views where appropriate.
- FR-OCR-10: Require confirmation for material profile changes.

## 14. Identity & Relationship Graph

- FR-ID-01: Represent the account owner as the primary identity.
- FR-ID-02: People detected in documents start as unconfirmed entities.
- FR-ID-03: User can confirm relationships such as parent, sibling, spouse or child.
- FR-ID-04: Each person's documents and attributes remain associated with the correct person.
- FR-ID-05: Surface ambiguity and conflicts for review.
- FR-ID-06: Do not infer sensitive relationships without an appropriate confirmation workflow.

## 15. Smart Search

- FR-SEARCH-01: Search document name, type, category and extracted names.
- FR-SEARCH-02: Search keywords and metadata.
- FR-SEARCH-03: Later releases support semantic/natural-language search.
- FR-SEARCH-04: Example queries: my PAN card; sister's Aadhaar; documents with old address; passport expiring next year.
- FR-SEARCH-05: Search respects ownership, permissions and encryption boundaries.

## 16. Snap-to-Fill

- FR-SNAP-01: Capture or upload a paper/scanned/PDF form.
- FR-SNAP-02: OCR identifies text and labels.
- FR-SNAP-03: Detect likely input fields.
- FR-SNAP-04: AI maps fields to confirmed profile or relationship data.
- FR-SNAP-05: User reviews suggestions before generating a filled document.
- FR-SNAP-06: Show unmatched and ambiguous fields.
- FR-SNAP-07: Preview before export.
- FR-SNAP-08: Future versions export filled PDF/image.

## 17. Android Autofill

- FR-AUTO-01: Implement Android Autofill Service for the MVP.
- FR-AUTO-02: Respond to fields exposed by the Android Autofill framework.
- FR-AUTO-03: Map field hints/labels to confirmed profile fields.
- FR-AUTO-04: User selects a profile or suggested value before sensitive autofill when required.
- FR-AUTO-05: Never invent missing personal information.
- FR-AUTO-06: User can disable the service.
- FR-AUTO-07: Support only compatible apps/sites; universal compatibility is not guaranteed.
- FR-AUTO-08: Accessibility Service can be evaluated later only after privacy, policy and security review.

## 18. Security & Privacy Architecture

- SEC-01: Encrypt data in transit and at rest.
- SEC-02: Prefer client-side encryption for vault documents so the server stores ciphertext rather than routine plaintext.
- SEC-03: Use a unique random data-encryption key per document or suitable object.
- SEC-04: Use authenticated encryption such as AES-256-GCM or a modern equivalent.
- SEC-05: Store private keys in Android Keystore or equivalent secure hardware-backed storage where available.
- SEC-06: Use modern public-key cryptography for key wrapping/exchange.
- SEC-07: Evaluate Shamir's Secret Sharing or threshold cryptography for recovery.
- SEC-08: Normal access should not require an administrator passkey.
- SEC-09: Exceptional recovery/support access requires explicit user authorization, strong authentication, audit logging and narrow temporary scope.
- SEC-10: Do not claim zero-knowledge unless the implemented cryptographic and operational design actually prevents the service from decrypting user content.
- SEC-11: Minimize sensitive telemetry and metadata.
- SEC-12: Apply secure deletion, key rotation and revocation procedures.
- SEC-13: Perform threat modeling, penetration testing and independent security review before production.

## 19. Dual-Control / Two-Key Recovery

- The proposed security feature is a dual-control recovery model. Normal use is user-only: the user authenticates locally and decrypts their own documents.
- Exceptional recovery can require two independent approvals or cryptographic shares, for example user approval plus a controlled recovery component.
- A possible design is: document → random data key → encrypted document. The data key is protected using the user's key and a separate recovery mechanism. A threshold scheme can require 2-of-2 or 2-of-3 shares depending on the threat model.
- The exact cryptographic construction must be reviewed by a qualified cryptography/security professional before production.

## 20. High-Level Data Model

- User: user_id, authentication identifiers, security settings, created_at.
- ProfileField: field_id, user_id, field_name, protected value/reference, confidence, source_document_id, status, updated_at.
- Document: document_id, owner_id, type, display_name, encrypted blob reference, metadata, created_at, processed_at.
- DocumentEntity: entity_id, document_id, field_name, protected value/reference, confidence, provenance.
- Person: person_id, account_owner_id, display_name, confirmation_status.
- Relationship: relationship_id, from_person_id, to_person_id, relationship_type, confirmation_status.
- SearchIndex: protected/searchable references designed to minimize plaintext exposure.
- AuditEvent: event_id, actor_type, action, resource, timestamp, result, device/session context.

## 21. System Architecture

- Mobile UI → Local secure storage/crypto layer → upload gateway → encrypted object storage.
- Document processing can be on-device or server-side depending on privacy requirements. If cloud AI is used, the product must document what leaves the device, retention, vendor controls and consent.
- Services: Authentication, Vault, Document Processing, Profile/Knowledge, Search, Autofill, Snap-to-Fill, Notification, Audit and Billing.
- Apply least privilege, service isolation, secure secrets management and separate production roles.

## 22. Suggested Technology Stack

- Android/Kotlin for the Autofill MVP. Flutter can be used for cross-platform UI with a native Android Autofill bridge.
- **UI/Design system: Material Design 3 (Material You).** Use dynamic color theming, the MD3 component set (filled/outlined text fields, FABs, bottom sheets, cards), and MD3 elevation/typography tokens throughout — this keeps the app visually native to Android, gives free dark-mode and dynamic-color support, and matches user expectations for a system-level service like Autofill.
- OCR: Google ML Kit or Tesseract baseline; evaluate Google Document AI, Azure Document Intelligence or AWS Textract for higher-accuracy workloads.
- AI: Gemini, OpenAI or another approved model for classification/extraction subject to privacy and cost requirements.
- Local database: Room/SQLite. Server metadata: PostgreSQL where needed.
- Search: SQLite FTS for MVP; OpenSearch/vector retrieval at scale.
- Backend: FastAPI, Node.js or Spring Boot.
- Storage: encrypted object storage with strict IAM.
- Security: Android Keystore, TLS, AES-GCM, modern public-key cryptography, secure session management.

## 23. Main User Flows

- **Flow A — First Use:** install → sign in → explain privacy → request only necessary permissions → create local security protection.
- **Flow B — Upload:** add document → camera/gallery/PDF → preprocess → OCR → classify → extract → suggest name → user confirms → encrypt/store → enrich profile.
- **Flow C — Search:** query → filters/ranking → result → local authenticated decryption → view.
- **Flow D — Relationship:** detect another person → show evidence → user confirms relationship → link entity.
- **Flow E — Snap-to-Fill:** capture form → OCR → detect fields → map to profile → review → generate filled output.
- **Flow F — Autofill:** open compatible form → tap field → Android Autofill suggestion → user selects → fields populate → review and submit.
- **Flow G — Recovery:** start recovery → strong authentication/consent → threshold/recovery policy → temporary access or key recovery → audit event.

## 24. UI / UX Screens

- **Design system: Material Design 3 end to end** — MD3 dynamic color, MD3 typography scale, MD3 shape/elevation tokens, and standard MD3 components (top app bars, navigation bar, FAB, bottom sheets, filled cards) across every screen listed below.
- Home dashboard: profile completeness, recent documents, Autofill status and quick actions.
- Vault: search, categories, document cards and add/scan button.
- Add Document: Camera, Gallery/File, PDF and future integrations.
- Scanning: crop/quality guidance, OCR progress and privacy indicator.
- Extracted Info: document type, extracted fields, confidence, edit and confirm.
- Smart Search: natural-language query, filters and result previews.
- Relationships: visual graph with explicit confirmation.
- Snap-to-Fill: form preview, detected fields, suggested values and review.
- Autofill: compact system-native suggestions instead of a persistent overlay.
- Security: encryption status, active sessions, recovery settings, permissions and audit information.

## 25. Permissions

- Camera: request only when scanning.
- Photos/files: request only when importing.
- Notifications: optional and purpose-specific.
- Contacts: optional and only for a clearly defined feature.
- Accessibility: not required for the core MVP.
- Autofill Service: user explicitly enables it in Android settings.

## 26. Non-Functional Requirements

- Security: encryption, least privilege, secure key management and auditable sensitive actions.
- Privacy: data minimization, explicit consent and clear retention/deletion policies.
- Performance: benchmark scan, OCR and AI processing on representative devices.
- Reliability: uploads and processing should recover safely from network interruptions.
- Scalability: document storage and processing should scale independently.
- Accessibility: readable typography, screen-reader support, high contrast — MD3's built-in accessibility tokens (contrast-checked color roles, minimum touch targets) should be relied on rather than re-derived.
- Localization: architecture should support Indian languages and local date/address formats.
- Observability: logs and metrics must not leak document contents.

## 27. AI Guardrails

- AI extraction is a suggestion, not ground truth.
- Never silently overwrite verified profile information.
- Show source/provenance for important fields.
- Ask for confirmation when confidence is low or multiple people match.
- Do not infer unnecessary sensitive attributes.
- Do not expose one person's documents to another through search.
- Treat malicious document content and prompt injection as security threats.
- Schema-validate AI output before writing to the database.

## 28. MVP Scope

- Android application, built with Material Design 3 components.
- Authentication.
- Secure local vault.
- Image/PDF upload.
- On-device OCR.
- AI document classification and structured extraction for a limited set of document types.
- Automatic document naming.
- Profile editing and confirmation.
- Basic search.
- Android Autofill Service.
- Encryption in transit and at rest.
- Basic recovery design and audit events.

## 29. Phase 2

- Identity graph and relationship confirmation.
- Semantic search.
- Snap-to-Fill for images/PDFs.
- More document types.
- Conflict resolution.
- Profile provenance.
- Improved OCR and multilingual support.
- Secure cloud synchronization.

## 30. Phase 3 — Expansion

- Browser extension.
- Cross-platform clients.
- Enterprise/MSME onboarding.
- Document verification workflows.
- Business APIs.
- Family/team vaults with granular permissions.
- Advanced threshold recovery.
- Compliance and external security certification work.

## 31. Phase 4 — Long-Term Vision

- Agentic application assistance with explicit user approval.
- Automatic preparation of complex applications.
- Integration with approved identity/document ecosystems.
- Personal AI assistant that can locate, prepare and reuse information while maintaining user control.
- MSME workflows for KYC, employee onboarding, vendor registration, subsidies and compliance.

## 32. Monetization

- Freemium consumer plan with limited storage/features.
- Premium subscription for higher storage, advanced search, Snap-to-Fill, family features and advanced automation.
- Business subscriptions for employee/document workflows.
- Enterprise licensing for private deployments, integrations and SLAs.
- API/usage pricing for document intelligence and form automation.
- Do not sell personal document data; privacy should be a core promise.

## 33. Success Metrics

- Activation: percentage of new users who successfully process a first document.
- Document processing success rate.
- OCR/entity extraction accuracy by document type.
- Percentage of extracted fields confirmed.
- Search success rate.
- Autofill completion rate.
- Snap-to-Fill field-mapping accuracy.
- Monthly active users and retention.
- Premium conversion.
- Cost per processed document.
- Security incidents and attempted incidents.
- Recovery success rate.

## 34. Risks & Mitigations

- Risk: OCR errors → preprocessing, confidence scoring, user confirmation and document-specific evaluation.
- Risk: AI hallucination → schemas, provenance, validation and confirmation.
- Risk: wrong-person association → identity graph and explicit confirmation.
- Risk: data breach → client-side encryption, secure key storage, least privilege and security testing.
- Risk: autofill incompatibility → Android Autofill first; browser extension later; no universal compatibility claim.
- Risk: cloud AI privacy → minimize data and prefer on-device processing where feasible.
- Risk: regulatory exposure → legal/privacy review before production.
- Risk: feature overload → focused MVP and validation before expansion.
- **Risk: an incumbent closes the gap** (e.g., DigiLocker adds extraction, or a password manager adds document OCR) → the durable moat has to be execution speed on the paper+digital bridge, deep Indian document-type coverage, and trust built through demonstrable privacy architecture — not the mere existence of the feature combination, since any single competitor could copy one piece at a time.

## 35. Hackathon Demo Script

1. Create a test user.
2. Scan/upload a sample identity document.
3. Show OCR extraction.
4. Show AI classification and automatic naming.
5. Confirm extracted profile information.
6. Upload a second document and show profile enrichment.
7. Search by person/document name.
8. Demonstrate relationship confirmation using a family document.
9. Photograph a sample paper form and show Snap-to-Fill mapping.
10. Open a compatible Android/web form and demonstrate Autofill.
11. Show security controls and explain encrypted storage and user-controlled access.
12. End with: **Store once. Understand forever. Reuse everywhere.**

## 36. MVP Definition of Done

- Core requirements have test cases.
- At least three representative document types process end-to-end.
- Extracted profile values require confirmation before becoming trusted.
- Vault search returns the correct document.
- Android Autofill fills a controlled set of test forms.
- Sensitive documents are encrypted and authenticated.
- Failed OCR, uploads and network interruptions are handled gracefully.
- Security threat model is documented.
- Privacy/data-flow documentation is prepared.
- Demo is reproducible on a clean test device, built with Material Design 3 UI throughout.

## 37. Final Product Statement

- AI Form & Vault turns documents into reusable, structured knowledge. It organizes documents automatically, extracts useful information, allows users to search by meaning, maps confirmed information to paper and digital forms, and provides native Android Autofill where supported.
- The long-term product is privacy-first: users control access to their information, routine server access to plaintext is avoided, exceptional recovery uses strong cryptographic controls, and AI suggestions remain subject to user confirmation.
- **Ultimate vision:** Store information once. Understand it forever. Reuse it everywhere.

## Appendix — Priority Roadmap

| Area | MVP | Phase 2 | Future |
|---|---|---|---|
| Vault | Required | Enhanced | Advanced |
| OCR | Required | Multilingual | Specialized |
| AI extraction | Required | Improved | Agents |
| Search | Basic | Semantic | Agentic |
| Autofill | Android | Improved | Cross-platform |
| Snap-to-Fill | Prototype | Required | Advanced |
| Identity graph | Basic | Required | Advanced |
| Security | Encryption + auth | Recovery | External audits |
| Business | Not required | Pilot | Enterprise |
| UI System | Material Design 3 | MD3 refinements | MD3 (cross-platform parity) |