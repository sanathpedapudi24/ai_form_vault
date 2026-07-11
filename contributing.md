

## 1. Commit & push code

```bash
git add -A
git commit -m "Your commit message"
git push origin main
```

## 2. Bump the version (pubspec.yaml)

Edit `version:` at the top of `pubspec.yaml`, e.g. `2.0.0+2` → `2.1.0+3`, then:

```bash
git add pubspec.yaml
git commit -m "Bump version to 2.1.0"
git push origin main
```

## 3. Tag the release

```bash
git tag -a v2.1.0 -m "v2.1.0 - short summary"
git push origin v2.1.0
```

## 4. Build the release APK

```bash
flutter build apk --release
```
Output lands at `build/app/outputs/flutter-apk/app-release.apk`.

## 5. Create the GitHub release (with notes)

```bash
gh release create v2.1.0 --title "v2.1.0 — short summary" --notes-file release_notes.md
```
(or swap `--notes-file` for `--notes "inline text"`)

## 6. Attach the APK to that release

```bash
gh release upload v2.1.0 build/app/outputs/flutter-apk/app-release.apk#AI-Form-and-Vault-v2.1.0.apk
```
The `#label` part is optional — it just sets the display name shown on the release page.

## All-in-one (once pubspec is already bumped and committed)

```bash
VERSION=v2.1.0
git push origin main
git tag -a $VERSION -m "$VERSION release"
git push origin $VERSION
flutter build apk --release
gh release create $VERSION --title "$VERSION" --notes "Release notes here"
gh release upload $VERSION build/app/outputs/flutter-apk/app-release.apk#AI-Form-and-Vault-$VERSION.apk
```

**One gotcha to remember**: if `flutter build apk --release` fails with an R8 "missing classes" error, that's the ML Kit ProGuard issue we already fixed in `android/app/proguard-rules.pro` — shouldn't recur unless you add a new plugin with the same kind of optional-dependency pattern.