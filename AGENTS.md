# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**AI Form & Vault** — Android app (Kotlin + Jetpack Compose, no DI framework, no networking) that stores identity/family documents scanned with on-device OCR and exposes search, fill, and share flows. Nothing leaves the device: no `INTERNET` permission, no account, no analytics.

## Commands

- Build: `.\gradlew.bat --console=plain :app:assembleDebug`
- Tests: `.\gradlew.bat --console=plain :app:testDebugUnitTest`
- Lint: `.\gradlew.bat --console=plain :app:lintDebug`
- JDK 17 required (local: `C:\Users\cherr\AppData\Local\Temp\opencode\jdk17\jdk-17.0.21+9`)

Always run the unit tests **and** `assembleDebug` locally before pushing.

## Stack versions

- Gradle 8.14.3, AGP 8.13.0, Kotlin 2.2.20, KSP `2.2.20-2.0.4`
- compileSdk / targetSdk 36, minSdk 26
- Room 2.7.2 + SQLCipher via `net.zetetic:sqlcipher-android:4.6.1`
- ML Kit Latin `com.google.android.gms:play-services-mlkit-text-recognition:19.0.1`; Devanagari `...-devanagari:16.0.2`

## Layout

```
app/src/main/java/com/aiformvault/
├── MainActivity.kt   Entry point; sets content, locks on resume
├── Model.kt          Domain types: documents, people, facts, profile derivation
├── Store.kt          Persistence, image storage, backup import/export, legacy migration
├── VaultDb.kt        Room rows, @Database, DAO, row ↔ VaultData mapping
├── Lock.kt           PIN hashing, cooldown, feature toggles
├── Ocr.kt            ML Kit wrapper, adaptive multi-pass pipeline, Devanagari fallback
├── Extractor.kt      Text → document type + facts (regex + heuristics)
├── Matching.kt       Label→fact mapping, fuzzy names, on-device search
├── Duplicates.kt     Identity-key normalisation and duplicate comparison
├── Services.kt       System autofill service + expiry reminder worker
└── ui/               Main.kt (AppState, navigation), Gate.kt, Profile.kt, Docs.kt
app/src/test/java/com/aiformvault/   Pure JVM unit tests (no Robolectric)
```

## Storage

- Room DB `vault.db` (SQLCipher-encrypted; random DB key sealed by Android Keystore key alias `vault`, in `filesDir/db.key`)
- Legacy migration: `vault.bin` → imported into DB → renamed `vault.bin.migrated` (fallback)
- Page images: `filesDir/img/<docId>_<page>.bin`
- Backup format: `.aivault` = `AIVAULT1` + 16-byte salt + AES-256-GCM ciphertext of zip (`vault.json`, `img/<id>_<page>.jpg`)

## Conventions

- Room row types, `@Database`, DAO colocated in single file `VaultDb.kt` (KSP2 cross-file `[MissingType]` bug workaround — do not split them back out)
- Row ↔ `VaultData` mapping must stay pure Kotlin/JVM-testable (no Context/Uri/Keystore); covered by `VaultRowsTest.kt`
- Vault state lives in in-memory `AppState`; it is the single source of truth for reads/writes
- OCR: adaptive multi-pass (plain → contrast → binarise → rotate), Devanagari fallback when Latin finds no usable name; `normalize()` is Unicode-aware
- Manual facts override extracted facts; duplicate detection is advisory-only
- Never make a fact silently "true": OCR output is a suggestion until the user confirms it

## Testing rules

- Tests are pure JVM (no Robolectric, no emulator); `unitTests.isReturnDefaultValues = true`
- Put logic that can be isolated from Android in a plain object (e.g. `Duplicates.kt`) and unit-test it there
- Baseline before this repo's current work: **56 tests, 0 failures**

## Known pitfalls

- SQLCipher: Room builder uses `.openHelperFactory(SupportOpenHelperFactory(passphrase))` (not `setOpenHelperFactory`) and the native library must be loaded with `System.loadLibrary("sqlcipher")`
- SQLCipher passphrase is raw bytes — a `String` will not bind; the DB key is 32 random bytes sealed by the Keystore key
- KSP2 error `[MissingType]: Element ... references a type that is not present` means an entity lives in a different file than the `@Database` class — colocate them
- The Devanagari ML Kit POM `19.0.1` 404s; pin `16.0.2`
- PowerShell 5.1 here has no `&&`, no `tail`/`ls -la`/`unzip`; `gh` breaks on unquoted commas — write a `.ps1` for complex commands

## Releases

- CI/CD workflow triggers on `v*` tags only; a push to `main` alone does **not** publish an APK — push a tag (`git tag vX.Y.Z; git push origin vX.Y.Z`)
- Release job signs with `RELEASE_*` secrets, hard-gates on `apksigner verify`; lint stays advisory
- Bump `versionCode` + `versionName` in `app/build.gradle.kts` and cut the matching `v*` tag
- Keep the same signing key forever; updates only install over an existing app when the certificate matches

## Design

- `SCREEN_DESIGN.html` — full-screen design artifact in repo root; awaiting human approval before implementation

## Issues

- Assigned to `charansaiponnada`: #8 Devanagari OCR, #9 batch import, #10 per-field re-read, #11 duplicate detection, #12 Room + SQLCipher
- One issue per commit; close the issue with a comment naming the commit and what changed
