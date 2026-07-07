# Setup

## Prerequisites

- Flutter stable, SDK `^3.10.4` (`flutter --version` to check)
- Android Studio (for the Android SDK/emulator) — this app is Android-first;
  the system-autofill feature is Android-only. Camera/OCR/vault features
  work on iOS too, but there is no iOS equivalent of the autofill service.
- An Android device or emulator on **API 26+** (autofill requires Oreo+).

```bash
flutter pub get
```

## Adding a Gemini API key (optional but recommended)

Without a key the app works fully offline: on-device OCR + a regex parser
extract Indian-document fields, search is keyword-only, and relationship
detection only picks up what the regex parser recognizes (currently
father's name). With a key, Gemini vision reads documents directly (higher
accuracy, handles regional scripts and handwriting better) and semantic
search understands natural-language queries.

1. Get a free key at [aistudio.google.com](https://aistudio.google.com) →
   "Get API key".
2. Copy the template:
   ```bash
   cp lib/core/config/api_keys.example.dart lib/core/config/api_keys.dart
   ```
3. Paste your key into `api_keys.dart`:
   ```dart
   class ApiKeys {
     ApiKeys._();
     static const String gemini = 'AIza...your-key...';
   }
   ```

`api_keys.dart` is gitignored — it will never be committed. The app detects
the key automatically at build time (`AppConfig.aiEnabled`); no other
config is needed. The Profile screen shows whether AI is active.

## Running

```bash
flutter run                 # debug, connected device/emulator
flutter build apk --debug   # just build, don't install
flutter build apk --release # release build (uses debug signing by default —
                             # see android/app/build.gradle.kts to add real
                             # signing before shipping)
```

## Enabling system-wide autofill

1. Open the app → **Profile** → toggle **System-wide autofill** on.
2. Android's "Choose autofill service" screen opens — select
   **AI Form & Vault**.
3. Other apps can now request your saved details (name, DOB, phone, email,
   address, PIN code, PAN, blood group, nationality — see
   [PRIVACY.md](PRIVACY.md) for exactly what's excluded).

You can verify which service is active from a shell at any time:

```bash
adb shell settings get secure autofill_service
```

## Tests & static analysis

```bash
flutter analyze   # should report "No issues found!"
flutter test      # unit tests (parser, search ranking) + widget tests
```

## Project structure

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full breakdown of
`lib/core`, `lib/features`, and the Android native layer.
