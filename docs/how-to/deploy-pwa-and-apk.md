# How to deploy the PWA and APK

WeatherGlass ships two artifacts from one codebase (see
[ADR-0006](../adr/0006-dual-pwa-apk-target.md)): a Progressive Web App on GitHub Pages
and a sideload APK on a release. Do the [build & code-gen steps](build-and-run.md)
first.

## PWA → GitHub Pages

```bash
flutter build web --base-href "/WeatherGlass/"
```

- The `--base-href` **must** match the Pages path (`/WeatherGlass/`), or asset URLs
  break.
- The boot spinner, service-worker self-heal, and `navigator.storage.persist()` call
  are baked into the **source** `web/index.html` — they are not re-spliced after each
  build, so a plain `flutter build web` already includes them. `persist()` matters: it
  asks the browser to keep the local Drift store from being evicted.
- Publish `build/web/` to the Pages branch/path for `WeatherGlass`. Add/refresh the
  landing card on the OpenHearth GitHub Pages site.

Verify after deploy: open the live URL, add a place, confirm the forecast renders and
**Settings → What leaves your device** shows the real URL.

## APK → sideload release

```bash
flutter build apk --split-per-abi --release
```

- `--split-per-abi` produces per-architecture APKs (smaller installs).
- Signed with the debug keystore (sideload distribution, not Play Store).
- Publish the APK as `WeatherGlass.apk` on the `v0-apk` release; link it from the
  landing card.

## Sanity checklist

- `flutter analyze` clean and `flutter test` green before building.
- The app label reads **WeatherGlass** (not "Glass") on the installed APK.
- No network egress other than Open-Meteo — check the browser Network tab on the live
  PWA (see [privacy-model § how you can check](../privacy-model.md#how-you-can-check-all-of-this-yourself)).
