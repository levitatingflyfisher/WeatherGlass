# WeatherGlass

A calm, local-first **weather** app for the home. *Read the sky, tell no one.*

WeatherGlass shows current conditions, the next hours, and the week ahead for the
places you care about — on a screen painted from the real sky. It is part of the
**OpenHearth** family of small, private, open-source apps for domestic life.

> **Vision, in one line:** you can read the sky without telling anyone where you are.
> WeatherGlass blurs your coordinate before it leaves the device, uses the one open,
> keyless weather source, and shows you the exact request. See **[VISION.md](VISION.md)**
> for the north star and **[docs/](docs/README.md)** for the full documentation.

## Why it's different

- **Local-first.** Your places and history live on your device. No account, no
  sign-in, no cloud.
- **Private by design.** Your location is rounded to a coarse grid (you choose
  how coarse — down to ~11 km) *before* anything is sent, and every request is
  keyless and cookieless: no API key, no token, no cache-buster, nothing that
  ties a request to you. That property is enforced by a test, not just a promise.
- **Honest.** Any direct request still shows the provider your IP — WeatherGlass says
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
flutter run -d chrome          # or: flutter build web --base-href "/WeatherGlass/"
flutter build apk --split-per-abi --release
```

## Documentation

Full docs are organized on the [Diátaxis](https://diataxis.fr/) model — start at
**[docs/README.md](docs/README.md)**. Highlights:

- **[VISION.md](VISION.md)** — the one idea, the invariants, the honest scorecard.
- **[docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md)** — how it fits together.
- **[docs/privacy-model.md](docs/privacy-model.md)** — the threat model and exactly what leaves the device.
- **[docs/reference/privacy-invariant.md](docs/reference/privacy-invariant.md)** — the coordinate-rounding rule, stated precisely and how the test enforces it.
- **[docs/whitepaper.md](docs/whitepaper.md)** — weather without surveillance: the case for the design.
- **[AGENTS.md](AGENTS.md)** — guide for anyone (agent or human) changing the code.

## Licence

WeatherGlass is free and open-source software. Weather data © Open-Meteo.com,
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
