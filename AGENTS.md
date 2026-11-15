# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**AI Form & Vault** — Android app (Kotlin + Jetpack Compose, no DI framework, no networking) that stores identity/family documents scanned with on-device OCR and exposes search, fill, and share flows.

## Commands

- Build: `.\gradlew.bat --console=plain :app:assembleDebug`
- Tests: `.\gradlew.bat --console=plain :app:testDebugUnitTest`
- Lint: `.\gradlew.bat --console=plain :app:lintDebug`
- JDK 17 required (local: `C:\Users\cherr\AppData\Local\Temp\opencode\jdk17\jdk-17.0.21+9`)

## Stack versions

- Gradle 8.14.3, AGP 8.13.0, Kotlin 2.2.20, KSP `2.2.20-2.0.4`
- compileSdk / targetSdk 36, minSdk 26
- Room 2.7.2 + SQLCipher via `net.zetetic:sqlcipher-android:4.6.1`
- ML Kit Latin `com.google.android.gms:play-services-mlkit-text-recognition:19.0.1`; Devanagari `...-devanagari:16.0.2`

## Storage

- Room DB `vault.db` (SQLCipher-encrypted; random DB key sealed by Android Keystore key alias `vault`, in `filesDir/db.key`)
- Legacy migration: `vault.bin` → imported into DB → renamed `vault.bin.migrated` (fallback)
- Page images: `filesDir/img/<docId>_<page>.bin`
- Backup format: `.aivault` = `AIVAULT1` + 16-byte salt + AES-256-GCM ciphertext of zip (`vault.json`, `img/<id>_<page>.jpg`)

## Conventions

- Room row types, `@Database`, DAO colocated in single file `VaultDb.kt` (KSP2 cross-file `[MissingType]` bug workaround)
- Row ↔ `VaultData` mapping must stay pure Kotlin/JVM-testable (no Context/Uri/Keystore); covered by `VaultRowsTest.kt`
- Vault state lives in in-memory `AppState`; it is the single source of truth for reads/writes
- OCR: adaptive multi-pass (plain → contrast → binarise → rotate), Devanagari fallback when Latin finds no usable name; `normalize()` is Unicode-aware
- Manual facts override extracted facts; duplicate detection is advisory-only

## Releases

- CI/CD workflow triggers on `v*` tags; release job signs with `RELEASE_*` secrets, hard-gates on `apksigner verify`, lint advisory
- Current version: `versionCode` 17, `versionName` "4.2.0"

## Design

- `SCREEN_DESIGN.html` — full-screen design artifact in repo root; awaiting human approval before implementation

## Issues

- Assigned to `charansaiponnada`: #8 Devanagari OCR, #9 batch import, #10 per-field re-read, #11 duplicate detection, #12 Room + SQLCipher
