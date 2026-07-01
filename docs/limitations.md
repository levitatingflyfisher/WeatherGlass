# Limitations

Read before adopting. WeatherGlass does a small thing well and says no to a lot on
purpose. This is the honest list of what it does *not* do, so nobody adopts it
expecting something it isn't. For the privacy-specific limits, see
[privacy-model.md § what honestly can't be hidden](privacy-model.md#what-honestly-cant-be-hidden).

## Held out of scope (a different app, not a TODO)

These are deliberate boundaries. Each would mean a second data source and/or push
infrastructure, which fights the single-keyless-source, no-backend design:

- **No severe-weather alerts.** Alerts come from national agencies over channels that
  need identifying requests or push — exactly what WeatherGlass avoids. Do not rely on
  it for warnings.
- **No radar or precipitation maps.** A different kind of data (tiles) from different
  sources.
- **No home-screen widget or notifications.** No background wake-ups; WeatherGlass only
  talks to the network while you're looking at it.
- **No historical weather / climate archive.** It shows a 7-day forecast window, not
  the past.

## Data and coverage

- **One provider.** Weather and geocoding are Open-Meteo only. If Open-Meteo is down or
  a location is poorly covered, there is no fallback source — that is the cost of the
  keyless, no-proxy stance ([ADR-0002](adr/0002-open-meteo-only.md)).
- **Aggregated models.** Open-Meteo blends ~15 national models (~11 km, ~1.5 km
  regionally). It is very good, but a local national service may occasionally be sharper
  for severe local weather.
- **Non-commercial free tier.** WeatherGlass uses Open-Meteo's free, non-commercial
  tier — fine for a no-ads family app, not licensed for a commercial redistribution.
- **Attribution is required.** "Weather data by Open-Meteo.com" (CC BY 4.0) must remain
  visible; it's shown on the forecast and the privacy screen.

## Privacy (the honest ceiling)

WeatherGlass minimises what it reveals; it does not anonymise. In short (full detail in
[privacy-model.md](privacy-model.md)): your **IP** is visible to the provider on any
direct request, the **place name** you search is sent to the geocoder, and the **set**
of coarse cells requested from one IP over time remains loosely correlatable. Rounding
and caching shrink the trail; they don't erase it. There is **no proxy** and **no
sync**.

## Platform

- **No iOS release.** The code targets Flutter and the pubspec has iOS config, but the
  shipped artifacts are the **PWA** and a **sideload APK** — iOS is not built or
  published.
- **PWA vs APK differ at the transport layer.** The browser sends a generic UA; the
  native app sends Dart's UA. Neither is per-user-trackable, but they are not identical.
- **Generated code is not committed.** `*.g.dart` (Drift, Riverpod) are gitignored; a
  fresh clone must run `build_runner` before it will build (see
  [how-to/build-and-run.md](how-to/build-and-run.md)).

## Testing reach

The domain and data layers — the privacy invariant, parsing, the living-sky palette,
units, caching — are well covered by unit tests, plus golden images for the forecast
view. There is no end-to-end integration test that drives a real network fetch through
the UI; live behavior has been verified manually (see `DECISIONS.md`). Widget goldens
have a known quirk: a `CustomPainter`'s `TextPainter` renders as tofu headless but fine
live.
