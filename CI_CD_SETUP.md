# CI/CD Setup — AI Form & Vault

This document explains how to set up the GitHub Actions pipeline that builds,
tests, lints, signs, and releases the APK to GitHub Releases.

## Pipeline overview

| Trigger | Job | What it does |
|---------|-----|--------------|
| Push to `main` / `develop` | `ci` | Unit tests → Android Lint → Debug APK → upload artifact |
| Pull request to `main` / `develop` | `ci` | Same as above (blocking check) |
| Push tag `v*` (e.g. `v4.1.0`) | `ci` → `release` | Tests → Lint → **signed Release APK** → GitHub Release + asset |

The `release` job depends on `ci` passing, so no broken build ever gets released.

## Files created

| File | Purpose |
|------|---------|
| `.github/workflows/ci-cd.yml` | GitHub Actions workflow (CI + Release) |
| `app/build.gradle.kts` | Added `signingConfigs.release` + `buildTypes.release` (reads signing values from env vars) |
| `gradle.properties` | Default signing property placeholders (empty passwords) |
| `app/proguard-rules.pro` | ProGuard/R8 rules for release minification |
| `.gitignore` | Excludes `release-keystore.jks`, `*.jks`, `*.keystore`, `*.key` |
| `CI_CD_SETUP.md` | This document |

## Required GitHub secrets

Go to your repo → **Settings → Secrets and variables → Actions** and add:

| Secret | Description | Example |
|--------|-------------|---------|
| `RELEASE_KEYSTORE_B64` | Base64-encoded release keystore file | `base64 -i release-keystore.jks` |
| `RELEASE_STORE_PASSWORD` | Keystore store password | `your-store-password` |
| `RELEASE_KEY_ALIAS` | Key alias inside the keystore | `upload` or `my-key` |
| `RELEASE_KEY_PASSWORD` | Key password (can equal store password) | `your-key-password` |

> ⚠️ Never commit `release-keystore.jks` or real passwords to git. They are excluded by `.gitignore`.

## Step 1 — Generate a release keystore (one time)

Run this locally (requires `keytool` from the JDK):

```bash
keytool -genkeypair -v \
  -keystore release-keystore.jks \
  -alias my-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=AI Form & Vault, O=Android, C=US"
```

Then encode it for the GitHub secret:

```powershell
# PowerShell (Windows)
[Convert]::ToBase64String((Get-Content -Path "release-keystore.jks" -Encoding Byte)) | Set-Clipboard
```

Paste the output into the `RELEASE_KEYSTORE_B64` secret.

## Step 2 — Add the four secrets

In GitHub repo settings → Secrets and variables → Actions → New repository secret:

1. `RELEASE_KEYSTORE_B64` — paste the base64 output from Step 1
2. `RELEASE_STORE_PASSWORD` — the store password you chose
3. `RELEASE_KEY_ALIAS` — e.g. `my-key`
4. `RELEASE_KEY_PASSWORD` — the key password you chose

## Step 3 — Create a release tag

The release job only runs when you push a tag matching `v*`:

```bash
git tag v4.1.1
git push origin v4.1.1
```

This triggers:
1. `ci` job (tests, lint, debug APK)
2. `release` job (signed release APK → GitHub Release with `app-release.apk` asset)

The release is created automatically with release notes. Download the APK from the GitHub Releases page.

## Step 4 — Versioning

Update `versionCode` and `versionName` in `app/build.gradle.kts` before tagging:

```kotlin
defaultConfig {
    versionCode = 16        // increment for every release
    versionName = "4.1.1"   // match the tag, e.g. v4.1.1
}
```

## Local verification (before pushing)

Run the same checks locally to catch issues early:

```bash
# Unit tests
./gradlew testDebugUnitTest

# Lint
./gradlew lintDebug

# Debug APK
./gradlew assembleDebug

# Release APK (needs signing env vars set)
export RELEASE_STORE_FILE=release-keystore.jks
export RELEASE_STORE_PASSWORD=...
export RELEASE_KEY_ALIAS=my-key
export RELEASE_KEY_PASSWORD=...
./gradlew assembleRelease
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `RELEASE_KEYSTORE_B64` secret missing | Add it in repo settings → Secrets → Actions |
| Keystore decode fails | Verify base64 string is valid; re-encode from the original `.jks` |
| APK not signed | Check all four secrets are set; ensure `app-release.apk` exists in `app/build/outputs/apk/release/` |
| Lint fails | Fix lint issues in `app/build/reports/lint-*.html` or add ProGuard rules |
