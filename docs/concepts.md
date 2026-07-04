# Concepts

The ideas WeatherGlass is built from. Each maps to a small, pure module in
`lib/features/weather/domain/` — the logic is deliberately kept out of the UI so it can
be unit-tested and reasoned about. For how they connect, see
[architecture/OVERVIEW.md](architecture/OVERVIEW.md).

## Precision and the rounded coordinate

The central concept. A **location precision** is how coarsely a coordinate is rounded
before it is stored or sent — the one privacy lever a browser app actually controls
(it cannot touch TLS or the User-Agent). There are three levels, each a number of
decimal places: `coarse` (1 dp, ~11 km cell), `balanced` (2 dp, ~1 km, the default),
`precise` (3 dp, ~110 m). `roundForPrecision(lat, lon, precision)` snaps a coordinate
to that grid; it is applied at the boundary, so only the coarse cell is ever persisted
or queried. This is specified rigorously in
[reference/privacy-invariant.md](reference/privacy-invariant.md) — it is *the* thing to
understand about WeatherGlass. (`domain/geo.dart`)

## Weather condition (WMO codes)

Open-Meteo reports weather as a numeric **WMO code** (0 = clear, 3 = overcast, 61–65 =
rain, 95 = thunderstorm, and so on — ~28 values). `conditionFromWmo` collapses these
into the fifteen conditions a person actually distinguishes (a `WeatherCondition`
enum), each with a plain label and a Lucide icon; an unknown code falls back to
`overcast` rather than throwing. Clear and partly-cloudy swap between sun and moon
glyphs by time of day. (`domain/weather_code.dart`)

## The living sky (the signature)

WeatherGlass's aesthetic bet: the hero background is painted from the *real* current
condition and time of day, so the screen looks like the sky outside the window.
`skyFor(condition, isDay)` is a **pure, deterministic** function returning a
`SkyPalette` — a top-to-bottom gradient plus an "ink" colour chosen to stay legible on
it (dark ink on bright skies, near-white on dark ones). Being pure is what makes the
hero testable and repeatable: a clear day and a clear night are different skies, a
storm is darker than clear daytime, and the same inputs always give the same palette.
(`domain/sky.dart`)

## Units — request metric, display anything

WeatherGlass always *requests* metric from the provider and converts for display on the
device. This is both simpler and a privacy property: because the unit preference never
changes the request URL, it can't become a fingerprint. `UnitSystem` (metric/imperial)
carries the suffixes; `formatTemp`, `formatWind`, `formatPrecip` do the conversion and
formatting. (`domain/units.dart`)

## Saved places and the forecast cache

A **saved place** is a name plus an already-rounded coordinate (Drift `SavedLocations`).
One special entry, "My location", is the device fix — re-resolved and re-rounded on
demand rather than tracked continuously. A **forecast cache** entry is the raw
Open-Meteo JSON for a place plus when it was fetched (Drift `ForecastCache`). A cached
copy under the 30-minute TTL is served with no network call — instant, offline-friendly,
and privacy-minded (fewer requests to correlate). A row that fails to parse (e.g. left
by an older build, or a valid-JSON-but-empty `200`) is evicted and refetched rather than
throwing forever. (`data/weather_repository.dart`, `data/locations_repository.dart`)

## The transparency screen

Not a domain concept but the product's conscience: **"What leaves your device"**
(`features/settings/presentation/privacy_screen.dart`) renders the *actual*
`forecastUrl` for one of your saved places, a "never sent" checklist, the honest IP
caveat, and the precision control. The claims elsewhere in these docs are things a user
can read off their own screen. See [privacy-model.md](privacy-model.md).
