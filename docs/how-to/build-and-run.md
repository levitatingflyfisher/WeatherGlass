# How to build & run WeatherGlass

From a fresh clone to a running app. Assumes a working Flutter toolchain
(SDK `>=3.3.0`); check with `flutter doctor`.

## 1. Get dependencies

```bash
flutter pub get
```

## 2. Generate code (required — do not skip)

Drift and Riverpod generate `*.g.dart` files, which are **gitignored**. A fresh clone
has none, so `flutter build`/`flutter test` will fail with "No such file or directory"
on `*.g.dart` imports until you run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Re-run this after changing a Drift table, a `@riverpod` provider, or dependencies.

## 3. Run it

```bash
flutter run -d chrome     # web / PWA
flutter run -d <device>   # a connected Android device or emulator
```

Add a place (search a town, or "Use my location"), and open **Settings → What leaves
your device** to see the actual request WeatherGlass makes.

## 4. Test, analyze, format

```bash
flutter test        # unit + golden suite — must be green before you commit
flutter analyze     # static analysis — zero issues expected
dart format .       # formatting
```

To run just the privacy-critical tests:

```bash
flutter test test/features/weather/geo_test.dart \
             test/features/weather/open_meteo_client_test.dart
```

See [verify-the-privacy-invariant.md](verify-the-privacy-invariant.md) for what those
prove.

## Notes

- **Android:** Java 25 is supported; the Gradle wrapper is pinned in
  `android/gradle/wrapper/gradle-wrapper.properties`, and core-library desugaring is
  enabled in `android/app/build.gradle.kts`.
- **Web + Drift:** the sqlite3 WASM engine (`web/sqlite3.wasm`) and the drift worker
  (`web/drift_worker.js`) are shipped in `web/` and pointed at from
  `core/storage/app_database.dart`; without them, web startup throws.
