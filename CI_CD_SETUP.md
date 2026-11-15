# CI/CD Setup — AI Form & Vault

GitHub Actions pipeline that tests, lints, builds, signs and publishes the APK.

## Pipeline at a glance

| Trigger | Workflow | Jobs | Result |
|---------|----------|------|--------|
| Push to `main` / `develop` | `CI / CD — Android APK Build & Release` | `build` | Tests + lint + **debug APK** artifact |
| Pull request to `main` / `develop` | same | `build` | Tests + lint + **debug APK** artifact |
| Push tag `v*` | same | `build` → `release` | **Signed release APK** + GitHub Release |
| Push tag `v*` (fork without signing secrets) | same | `build` → `release` | Tests/APK run; release emits a warning and is skipped |
| Manual | same | `build` | Same as push |

`concurrency` cancels superseded PR runs, so only the newest push per branch runs.

## Current status

> **Configured and working.** All four signing secrets are set, and the first signed release shipped on 2026-11-15.

| | |
|---|---|
| Last green CI run | `43686300572` — 3m29s, all steps passed |
| First signed release | [`v4.1.1`](https://github.com/sanathpedapudi24/ai_form_vault/releases/tag/v4.1.1) — run `43686985479` |
| Published asset | `ai-form-vault-4.1.1.apk` (9,645,111 bytes) |
| Signing certificate SHA-256 | `F4:62:58:40:79:8E:1E:9C:D1:D1:AE:14:BE:6B:FE:1D:70:E9:2C:BC:57:0D:75:E0:86:EC:8A:67:25:46:6B:90` |
| Secrets present | `RELEASE_KEYSTORE_B64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD` |

Steps 1 and 2 below are kept as reference — they are already done for this repository and only need repeating for a fork or a new app.

## Files

| File | Purpose |
|------|---------|
| `.github/workflows/ci-cd.yml` | The workflow: `build` (CI) + `release` (sign & publish) |
| `app/build.gradle.kts` | Opt-in release signing from env vars; Java 17; Compose |
| `app/proguard-rules.pro` | R8/ProGuard rules for release builds |
| `gradle.properties` | Gradle JVM args, parallel + build cache, AndroidX |
| `.gitignore` | Excludes `*.jks`, `*.keystore`, `*.key` |
| `CI_CD_SETUP.md` | This document |

## Why the previous pipeline failed

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Warning: Failed to find package 'tools'` → `sdkmanager` exit 1 | `android-actions/setup-android@v3` defaults to installing the legacy `tools` package, which Google removed from the SDK repo | Moved to `android-actions/setup-android@v4` (default is `platform-tools`) and install the exact platform/build-tools with `sdkmanager` |
| Run fails in 0s, "workflow file issue" | `if: ... && secrets.RELEASE_KEYSTORE_B64 != ''` — the `secrets` context is **not** available in a job-level `if` | Job-level `if` only uses `github.ref`; secrets are read from job-level `env` inside step-level `if`s |
| `ci` skipped on tags → `release` (which `needs: ci`) never ran | `ci` had `if: ... || !startsWith(refs/tags/)` | `build` runs on tags too; `release` gates on `startsWith(github.ref, 'refs/tags/v')` |
| GitHub Release step 403 | Default `GITHUB_TOKEN` is read-only | `permissions: contents: write` on the `release` job only |
| Silent unsigned release | Gradle applied signing config even when env vars were empty | Signing applied only when all four env vars exist **and** the keystore file exists |

## GitHub secrets (already configured)

**Repo → Settings → Secrets and variables → Actions**

| Secret | Description | Status |
|--------|-------------|--------|
| `RELEASE_KEYSTORE_B64` | Base64-encoded release keystore (`.jks`) | ✅ set |
| `RELEASE_STORE_PASSWORD` | Keystore store password | ✅ set |
| `RELEASE_KEY_ALIAS` | Key alias inside the keystore (`ai-form-vault`) | ✅ set |
| `RELEASE_KEY_PASSWORD` | Key password (equals the store password for PKCS12) | ✅ set |

> These secrets are read by the `release` job only. On a fork without them, CI still passes and the debug APK is still produced — the release job emits a warning and skips signing.

The keystore itself and its password file (`release-keystore.jks`, `release-keystore-credentials.txt`) are **not** in the repository — both are git-ignored. Keep an offline backup: if the keystore is lost, no future update can be installed over the published app.

## Step 1 — Create a release keystore (done for this repo)

```bash
keytool -genkeypair -v \
  -keystore release-keystore.jks \
  -alias ai-form-vault \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=AI Form & Vault, O=AI Form Vault, C=IN"
```

> **PKCS12 note:** modern `keytool` writes PKCS12 keystores, which do not support separate store and key passwords — it warns and silently uses the store password for both. Set `RELEASE_KEY_PASSWORD` to the **same value** as `RELEASE_STORE_PASSWORD`, or signing will fail with a wrong-password error.

Base64-encode it for the `RELEASE_KEYSTORE_B64` secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks")) | Set-Clipboard
```

```bash
# macOS / Linux
base64 -w0 release-keystore.jks | pbcopy
```

## Step 2 — Add the four secrets (done for this repo)

Use the table above. Never commit `release-keystore.jks` (it is git-ignored).

## Step 3 — Cut a release

1. Bump the version in `app/build.gradle.kts`:
   ```kotlin
   versionCode = 17        // must increase every release
   versionName = "4.1.2"   // must match the tag without the leading v
   ```
2. Commit, then tag and push:
   ```bash
   git commit -am "release: 4.1.2"
   git push origin main
   git tag -a v4.1.2 -m "AI Form & Vault 4.1.2"
   git push origin v4.1.2
   ```
3. The `build` job runs first; then `release` signs the APK, verifies it with `apksigner`, and attaches `ai-form-vault-4.1.2.apk` to a GitHub Release.

## Local verification

```bash
./gradlew testDebugUnitTest   # unit tests
./gradlew lintDebug           # Android lint
./gradlew assembleDebug       # debug APK  -> app/build/outputs/apk/debug/app-debug.apk
```

Signed release build (PowerShell):

```powershell
$env:RELEASE_STORE_FILE="C:\path\to\release-keystore.jks"
$env:RELEASE_STORE_PASSWORD="..."
$env:RELEASE_KEY_ALIAS="my-key"
$env:RELEASE_KEY_PASSWORD="..."
.\gradlew assembleRelease
```

Without those variables `assembleRelease` still works but produces an **unsigned** APK.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Android SDK not found` | Runner image changed; the workflow uses `ANDROID_SDK_ROOT`/`ANDROID_HOME` set by `setup-android` |
| `Gradle requires JVM 17+` | Install/point `JAVA_HOME` at JDK 17+ (CI does this via `actions/setup-java`) |
| `RELEASE_KEYSTORE_B64 is not configured` warning | Add the four secrets; the tag built but nothing was published |
| `keytool -list` fails in the release job | The base64 secret is corrupt — re-encode the original keystore |
| `apksigner verify` fails | Missing/incorrect `RELEASE_STORE_PASSWORD` or `RELEASE_KEY_PASSWORD` |
| Gradle out of memory | Raise `org.gradle.jvmargs` in `gradle.properties` |
| Lint failures | Download the `lint-report` artifact; lint is non-blocking on purpose |
