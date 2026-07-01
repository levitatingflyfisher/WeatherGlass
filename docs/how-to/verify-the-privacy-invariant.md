# How to verify the privacy invariant

WeatherGlass's central claim — *a forecast request carries only a coarse cell and no
identifier* — is meant to be checked, not trusted. Here are four independent ways, from
fastest to most thorough. The claim is stated precisely in
[reference/privacy-invariant.md](../reference/privacy-invariant.md).

## 1. Run the tests (30 seconds)

```bash
flutter test test/features/weather/geo_test.dart \
             test/features/weather/open_meteo_client_test.dart
```

- `geo_test.dart` proves rounding is correct per precision and that a coarser setting
  never reveals more than a finer one.
- `open_meteo_client_test.dart` proves the forecast URL carries **exactly** the fixed
  parameter set plus the rounded coordinates — no key, token, cache-buster, userinfo, or
  fragment — and that only the coordinates vary between two locations.

If either fails, the privacy claim is broken; that is the point of the tests.

## 2. Read the two functions (2 minutes)

- [`domain/geo.dart`](../../lib/features/weather/domain/geo.dart) —
  `roundForPrecision` is the rounding. ~20 lines.
- [`data/open_meteo_client.dart`](../../lib/features/weather/data/open_meteo_client.dart) —
  `forecastUrl` assembles the request in one place, from a `const` parameter map.

Confirm there is no parameter you didn't expect and no header being set.

## 3. See the real request in-app (1 minute)

Run WeatherGlass, add a place, then open **Settings → What leaves your device**. It
prints the *actual* URL for that place — copy it, inspect it. The only per-user part is
the coordinate, and it's rounded to your chosen cell.

## 4. Watch the wire (5 minutes)

Run the PWA (`flutter run -d chrome`), open DevTools → Network, and add a place. You'll
see exactly two request types: a `geocoding-api.open-meteo.com/v1/search?name=…` (the
name you typed) and an `api.open-meteo.com/v1/forecast?…` (rounded coords + fixed
params). Nothing else — no analytics beacon, no font CDN, no key.

## If you're adding a feature

Any change that puts a new query parameter on the forecast request, or reaches the
network with a location that hasn't been rounded, is a **privacy change**. It must (a)
make `open_meteo_client_test.dart` fail so the change is visible, and (b) be justified —
not merged as a silent "harmless" addition. See
[AGENTS.md § non-negotiables](../../AGENTS.md#non-negotiables-breaking-one-is-a-regression-not-a-feature).
