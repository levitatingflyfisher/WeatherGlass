# Glass

A calm, local-first **weather** app for the home. *Read the sky, tell no one.*

Glass shows current conditions, the next hours, and the week ahead for the
places you care about — on a screen painted from the real sky. It is part of the
**OpenHearth** family of small, private, open-source apps for domestic life.

## Why it's different

- **Local-first.** Your places and history live on your device. No account, no
  sign-in, no cloud.
- **Private by design.** Your location is rounded to a coarse grid (you choose
  how coarse — down to ~11 km) *before* anything is sent, and every request is
  keyless and cookieless: no API key, no token, no cache-buster, nothing that
  ties a request to you. That property is enforced by a test, not just a promise.
- **Honest.** Any direct request still shows the provider your IP — Glass says
  so plainly on its "What leaves your device" screen rather than pretending
  otherwise. It just reveals as little as possible around that.
- **No ads, no trackers, no analytics.**

## Data

Weather and place search come from [Open-Meteo](https://open-meteo.com), the
only fully open-source weather source — keyless, CORS-friendly, and licensed
**CC BY 4.0**. Forecasts are attributed in-app.

## Build

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome          # or: flutter build web --base-href "/Glass/"
flutter build apk --split-per-abi --release
```

## Licence

Glass is free and open-source software. Weather data © Open-Meteo.com,
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
