# CI/CD Setup — AI Form & Vault

GitHub Actions pipeline that tests, lints, builds, signs and publishes the APK.

## Pipeline at a glance

| Trigger | Workflow | Jobs | Result |
|---------|----------|------|--------|
| Push to `main` / `develop` | `CI / CD — Android APK Build & Release` | `build` | Tests + lint + **debug APK** artifact |
| Pull request to `main` / `develop` | same | `build` | Tests + lint + **debug APK** artifact |
| Push tag `v*` | same | `build` → `release` | **Signed release APK** + GitHub Release |
| Push tag `v*` with no signing secrets | same | `build` → `release` | Tests/APK run; release emits a warning and is skipped |
| Manual | same | `build` | Same as push |

`concurrency` cancels superseded PR runs, so only the newest push per branch runs.

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

## Required GitHub secrets

**Repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret | Description |
|--------|-------------|
| `RELEASE_KEYSTORE_B64` | Base64-encoded release keystore (`.jks`) |
| `RELEASE_STORE_PASSWORD` | Keystore store password |
| `RELEASE_KEY_ALIAS` | Key alias inside the keystore |
| `RELEASE_KEY_PASSWORD` | Key password |

> These secrets are read by the `release` job only. Without them, CI still passes and the debug APK is still produced.

## Step 1 — Create a release keystore (one time)

```bash
keytool -genkeypair -v \
  -keystore release-keystore.jks \
  -alias my-key \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=AI Form & Vault, O=Android, C=US"
```

Base64-encode it for the `RELEASE_KEYSTORE_B64` secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks")) | Set-Clipboard
```

```bash
# macOS / Linux
base64 -w0 release-keystore.jks | pbcopy
```

## Step 2 — Add the four secrets

Use the table above. Never commit `release-keystore.jks` (it is git-ignored).

## Step 3 — Cut a release

1. Bump the version in `app/build.gradle.kts`:
   ```kotlin
   versionCode = 16        // must increase every release
   versionName = "4.1.1"   // must match the tag without the leading v
   ```
2. Commit, then tag and push:
   ```bash
   git commit -am "release 4.1.1"
   git tag v4.1.1
   git push origin main --tags
   ```
3. The `build` job runs first; then `release` signs the APK, verifies it with `apksigner`, and attaches `ai-form-vault-4.1.1.apk` to a GitHub Release.

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
