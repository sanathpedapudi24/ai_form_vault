# CI/CD Setup — AI Form & Vault

Fixed GitHub Actions pipeline that builds, tests, lints, signs, and releases the APK.

## Pipeline Overview

| Trigger | Job | What it does |
|---------|-----|--------------|
| Push to `main` / `develop` | `ci` | Unit tests → Android Lint → Debug APK → upload artifact |
| Pull request to `main` / `develop` | `ci` | Same as above (blocking check) |
| Push tag `v*` + keystore secret | `release` | Tests → Lint → **signed Release APK** → GitHub Release + asset |
| Push tag `v*` + NO keystore | `release-no-keystore` | Warns that release is skipped |

## Files

| File | Purpose |
|------|---------|
| `.github/workflows/ci-cd.yml` | GitHub Actions workflow (CI + Release + fallback) |
| `app/build.gradle.kts` | Optional release signing (only if env vars present) + Google/Maven repos |
| `app/proguard-rules.pro` | ProGuard/R8 rules for release |
| `gradle.properties` | Gradle JVM args + caching |
| `.gitignore` | Excludes `release-keystore.jks`, `*.jks`, `*.keystore`, `*.key` |
| `CI_CD_SETUP.md` | This document |

## Required GitHub Secrets

Go to **Repo Settings → Secrets and variables → Actions** and add:

| Secret | Description | Required for |
|--------|-------------|--------------|
| `RELEASE_KEYSTORE_B64` | Base64-encoded release keystore | Release APK |
| `RELEASE_STORE_PASSWORD` | Keystore store password | Release APK |
| `RELEASE_KEY_ALIAS` | Key alias inside the keystore | Release APK |
| `RELEASE_KEY_PASSWORD` | Key password | Release APK |

> ⚠️ Never commit `release-keystore.jks` or real passwords. They are excluded by `.gitignore`.

## Step 1 — Generate a release keystore (one time)

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

Encode it for GitHub secret:

```powershell
# PowerShell
[Convert]::ToBase64String((Get-Content -Path "release-keystore.jks" -Encoding Byte)) | Set-Clipboard
```

Paste into `RELEASE_KEYSTORE_B64` secret.

## Step 2 — Add the four secrets

In GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

1. `RELEASE_KEYSTORE_B64` — paste base64 output
2. `RELEASE_STORE_PASSWORD` — your store password
3. `RELEASE_KEY_ALIAS` — e.g. `my-key`
4. `RELEASE_KEY_PASSWORD` — your key password

## Step 3 — Create a release tag

```bash
git tag v4.1.1
git push origin v4.1.1
```

This triggers:
1. `ci` job (tests, lint, debug APK)
2. `release` job (signed release APK → GitHub Release with `app-release.apk`)

If keystore secret is missing, `release-no-keystore` runs instead and just warns.

## Step 4 — Versioning

Update `versionCode` and `versionName` in `app/build.gradle.kts` before tagging:

```kotlin
defaultConfig {
    versionCode = 16        // increment for every release
    versionName = "4.1.1"   // match the tag, e.g. v4.1.1
}
```

## Local verification

```bash
# Unit tests
./gradlew testDebugUnitTest

# Lint (debug)
./gradlew lintDebug

# Debug APK
./gradlew assembleDebug

# Release APK (needs signing env vars)
export RELEASE_STORE_FILE=release-keystore.jks
export RELEASE_STORE_PASSWORD=...
export RELEASE_KEY_ALIAS=my-key
export RELEASE_KEY_PASSWORD=...
./gradlew assembleRelease
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `RELEASE_KEYSTORE_B64` secret missing | Add it in repo Settings → Secrets → Actions |
| Keystore decode fails | Verify base64 string is valid; re-encode from original `.jks` |
| APK not signed | Check all four secrets are set; ensure `app-release.apk` exists |
| Lint fails | Fix issues in `app/build/reports/lint-*.html` or add ProGuard rules |
| Gradle OOM | Increase `GRADLE_OPTS` heap (currently 4g) |
| `compileSdk 36` not available | Android SDK setup action installs it automatically |
