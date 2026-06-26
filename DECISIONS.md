# WeatherGlass — design decisions

A calm, local-first FLOSS **weather** app for the OpenHearth fleet. PWA-first
(Flutter) + sideload APK, like Furrow. Tagline: *"Read the sky. Tell no one."*

## Name
**WeatherGlass** — the household *weather-glass* (the barometer by the door). Pairs
with **Sundial** in the fleet (two antique domestic instruments), and carries the
thesis: your own instrument, read at home, telling no one. Shipped first under the
working name **Glass**, then renamed to **WeatherGlass** (2026-06-25) — "Glass"
alone was ambiguous (Google Glass, generic), and "WeatherGlass" disambiguates while
keeping the weather-glass metaphor. ("Welkin"/"Vane" were dropped earlier for
collisions with existing weather apps.) Internal package id stays `glass`
(invisible to users).

## Data source — Open-Meteo, only (from deep research)
Open-Meteo is the single best fit and the only one used:
- **The only genuine FLOSS source** (server AGPLv3, data CC-BY 4.0).
- **No API key**, **wildcard CORS** (a pure browser PWA calls it directly — no
  backend), **no cookies / no tracking** (all verified live).
- Near-global via ~15 aggregated national models (~11 km, regional ~1.5 km).
- Free tier is **non-commercial** — fine for a no-ads family app.
- Attribution required: "Weather data by Open-Meteo.com" (CC BY 4.0). Shown on
  every forecast + the privacy screen.
- Geocoding via the sibling keyless `geocoding-api.open-meteo.com`.

**Rejected:** MET Norway and NWS both *mandate an identifying User-Agent* a
browser cannot send (Chrome drops a JS-set UA), forcing a proxy — that fights
the no-backend, un-fingerprintable goal. Open-Meteo already aggregates DWD/MET
data anyway, so coverage isn't lost.

## Privacy — the differentiator, built as a tested invariant
The goal: an individual user is **not trackable by a unique request
fingerprint**. What a browser app can actually control is NOT headers/TLS
(JA3/JA4 and forbidden-header rules are out of JS's hands) — it's **location
precision** and **request volume**.
- **Coordinate rounding at the boundary** (`geo.dart`): a place's coordinates
  are rounded the moment it's added/located and only the coarse value is ever
  stored or sent. Precision is user-chosen: Coarse ~11 km / **Balanced ~1 km**
  (default) / Precise ~110 m.
- **Fixed, keyless request shape** (`open_meteo_client.dart`): `forecastUrl`
  carries only `latitude,longitude` + a constant param set — no key, token,
  cache-buster, or custom header. **This is pinned by a test**
  (`open_meteo_client_test.dart`): the URL's param-key set must equal the fixed
  allow-list and contain no identifier of any known shape. Treat any new query
  param as a privacy change, not a feature.
- **Units never touch the URL**: always request metric, convert client-side, so
  the unit preference can't add a fingerprint.
- **Aggressive caching** (`weather_repository.dart`, 30-min TTL): instant,
  offline-friendly, and fewer requests to correlate.
- **No backend**: direct browser→Open-Meteo. The IP leak is inherent to any
  direct request and is stated honestly on the privacy screen (we do not pretend
  to hide it; we minimise everything else). The *constellation* of saved places
  seen from one IP over time is still loosely correlatable — rounding + caching
  shrink that, they don't erase it.
- **PWA vs APK** differ at the UA/TLS layer (browser-generic on web; Dart's own
  UA on native) — neither is per-user-trackable. Said plainly, not over-claimed.
- The **"What leaves your device"** screen shows the *exact* request URL for a
  saved place, the never-sent list, the honest IP caveat, and the precision
  control.

## Architecture (forked from Furrow; Clean + Riverpod codegen + drift)
- **Domain (pure, TDD'd):** `geo` (rounding/precision), `weather_code`
  (WMO→condition+icon), `sky` (the signature palette), `units`.
- **Data:** `OpenMeteo` client (forecast + geocoding), `models` (parse the
  parallel-array JSON), `LocationsRepository` + `WeatherRepository` over drift
  (`SavedLocations`, `ForecastCache`), `GeolocationService` (coarse-only).
- **State:** Riverpod codegen providers; `Settings` notifier over
  SharedPreferences (units / precision / theme).
- **Presentation:** `HomeScreen` (a `PageView` of places, sky full-bleed,
  frosted "glass" controls), `ForecastView` (the signature), `LocationsScreen`,
  `AddLocationSheet` (search + coarse locate-me), `PrivacyScreen`,
  `SettingsScreen`.
- **Signature:** the **living sky** — `ForecastView`'s background gradient is
  drawn from the real current condition + day/night, so the screen looks like
  the sky outside. Pure `skyFor(condition, isDay)`, unit-tested.

## Scope (held deliberately)
In: current conditions, 24 h hourly, 7-day daily, multiple places (search +
coarse geolocation), cached/offline, the privacy controls + transparency.
Out (different sources / push / a different app): radar, severe-weather alerts,
home-screen widget. The living-sky hero is the one aesthetic risk; everything
else stays quiet.

## Deploy
PWA → gh-pages (`flutter build web --base-href "/WeatherGlass/"`). The boot spinner +
SW self-heal + `navigator.storage.persist()` are baked into **source**
`web/index.html` this time (no re-splicing on each push). APK →
`flutter build apk --split-per-abi --release` (debug-keystore) → `WeatherGlass.apk` on
a published `v0-apk` release. Landing card on `levitatingflyfisher.github.io`.
Repo `levitatingflyfisher/WeatherGlass` — clean history from commit 1, neutral persona
(no Claude, no personal domain).

## Verified
24 weather domain/data tests (incl. the 5-test privacy-invariant suite) + 36
total green; `flutter analyze` clean; forecast goldens swept (clear-day / rain /
clear-night) confirm the sky hero + layout with no overflow; live Open-Meteo
schema + CORS confirmed by curl during design.

## UI refinement round (2026-06-25, renamed app)
- **City switching made obvious.** Replaced cryptic page-dots with a strip of
  named, tappable **city tabs** (`_CityTabs` in home_screen) — current place
  highlighted, always visible when >1 place, so multi-city is discoverable (not
  hidden behind a swipe). PageView still swipes; tabs `animateToPage`. The
  forecast gets a `topInset` so its content clears the overlay (icons + tabs).
- **Hourly = a temperature curve, not number boxes.** `_HourlyGraph` /
  `_HourlyPainter` (CustomPaint): a Catmull-Rom-smoothed temp line with a soft
  gradient fill, temp labels on the data, condition glyphs (drawn via TextPainter
  + the lucide icon font), and precip as quiet bars. Scaled to the window's own
  min/max so the day's shape reads. Tufte-spirited (data-ink, no chartjunk).
- **Daily = Apple-style range bars.** `_RangeBar`: each day's low→high as a bar
  placed + sized against the whole week's span and tinted by a cold→warm ramp —
  warm days sit right, cold left; bar length = the day's swing.
- **Privacy copy toned down** (user: "overbearing"). Dropped the "Read the sky,
  tell no one" tagline from the empty state, Settings/About, and the manifest/
  index descriptions; the empty state now leads with weather. Removed the
  per-forecast "What leaves your device" link (privacy still lives in Settings).
- **Golden gotcha:** a CustomPainter's `TextPainter` text/icons render as tofu in
  headless goldens (no font loaded) but render fine LIVE — verified by a live
  Playwright drive (real temp labels on the curve, real moon/cloud glyphs).
  Also: `intl` exports a `TextDirection` that clashes with Flutter's — import
  intl with `hide TextDirection` when using `TextPainter`.
- Deployed + live-verified at /WeatherGlass/; APK synced.

### Deep-research refinements (Apple Weather + Breezy/Geometric + Tufte)
The research (101 agents, 23/25 claims confirmed) validated the design and added
two concrete patterns:
- **"Now" dot on today's range bar** (Apple): a white dot (sky-coloured ring)
  marks where the *current* temperature falls within today's low→high bar — only
  on today's row. Live-verified.
- **Places = a directly-accessible overview** (research: "page/progress dots are
  weak signifiers users miss; a directly-accessible list is clearest"). The
  Places screen now shows each saved city's current temp + condition glyph
  (cache-aware), and tapping a city jumps Home to it via `selectedCityIdProvider`
  (Home listens + `animateToPage`). Live-verified (Berlin 32°☀ / London 35°☁).
- Confirmed-as-is by the research: the **smooth hourly temp curve + gradient
  fill** (Breezy's "conditions trend" + Tufte sparkline — data-ink 1.0, no
  gridlines/axes) and the **week-scaled cold→warm daily range bars** (Apple). The
  research suggested fl_chart over a hand-rolled painter; kept the working
  CustomPainter (verified live, no new dep). Kept per-hour temp labels (usability)
  rather than Tufte's min/max-only — Apple/Breezy also show per-hour numbers.
