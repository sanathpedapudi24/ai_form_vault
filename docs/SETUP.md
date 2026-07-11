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

## Cloud AI: permanently off, by design

This app runs entirely on-device: on-device OCR + a regex parser extract
Indian-document fields, search is keyword + light natural-language
matching, and relationship detection picks up what the regex parser
recognizes (currently father's name). No document image or OCR text is
ever sent anywhere.

This isn't the state you get by leaving a key blank — `AppConfig.aiEnabled`
is a hardcoded `false`, and it's the single switch every network-touching
code path is gated on (see [PRIVACY.md](PRIVACY.md)). The Gemini
integration code (`gemini_client.dart`, `document_intelligence.dart`,
`embedding_service.dart`) is still in the repo — it's a real, working
integration — but pasting a key into `lib/core/config/api_keys.dart` will
**not** turn it back on. Re-enabling cloud AI means deliberately changing
`AppConfig.aiEnabled` back to reading the key, which is a call to make on
purpose, not a side effect of adding credentials.

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
