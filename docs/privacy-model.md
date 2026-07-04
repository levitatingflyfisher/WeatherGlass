# Privacy model

What WeatherGlass protects, what leaves the device, and — just as important — what it
*cannot* hide and does not pretend to. For the rule stated with full rigor, see
[reference/privacy-invariant.md](reference/privacy-invariant.md). For the design
rationale, [ADR-0003](adr/0003-coordinate-rounding-privacy-lever.md) and
[ADR-0004](adr/0004-no-backend-direct-request.md).

## Who this protects you from

A mainstream weather app's business is knowing where you are. WeatherGlass is built
so that the parties who *could* build a location trail get as little as possible:

- **The weather provider.** Open-Meteo is keyless and states it doesn't track, but the
  design does not depend on trusting that: a request carries no account, key, or token
  to *attach* a history to, and only a coarse cell to record.
- **A passive network observer** (ISP, Wi-Fi operator). Sees that you contacted a
  weather host, over TLS; sees a coarse cell only if it can read the query, which HTTPS
  protects.
- **Whoever picks up your unlocked device.** Finds only rounded coordinates and cached
  forecasts — never your exact home.

It does **not** try to defend against a global adversary correlating your IP across
services, or against malware on your device. Be clear-eyed about the threat model.

## Exactly what leaves the device

There are only three ways WeatherGlass talks to the network, and all three go directly
to Open-Meteo — no server of ours in between.

| # | When | Request | What the provider learns |
|---|---|---|---|
| 1 | Viewing a forecast | `GET api.open-meteo.com/v1/forecast` — rounded `latitude,longitude` + a fixed field set (see [invariant I2](reference/privacy-invariant.md#4-the-fixed-request-invariant-i2)) | A coarse grid cell (~1 km by default); your IP |
| 2 | Searching for a place | `GET geocoding-api.open-meteo.com/v1/search?name=…` | The place name you typed; your IP |
| 3 | "Use my location" (optional) | *No network call of its own* — the OS gives a low-accuracy fix, which is then rounded and used as request #1 | (as request #1) |

Requests are cached for 30 minutes, so viewing a forecast usually makes **no** request
at all. Metric is always requested and converted client-side, so your unit choice
never alters request #1.

**Nothing else leaves the device.** There is no analytics or telemetry SDK, no crash
reporter, no ad network, and no third-party asset fetched at runtime — the Lora/Nunito
fonts are bundled in the APK/PWA rather than pulled from Google Fonts
([ADR-0005](adr/0005-no-third-party-egress.md)).

## What stays on the device

- **Saved places** — stored **already rounded** (Drift `SavedLocations`).
- **Forecast cache** — the raw provider JSON per place (Drift `ForecastCache`).
- **Settings** — units, location precision, theme (SharedPreferences).

No account, no sign-in, no cloud, no sync. See [data model](reference/data-model.md).

## What honestly can't be hidden

WeatherGlass minimises; it does not magically anonymise. Stated plainly here and on the
in-app **"What leaves your device"** screen:

- **Your IP address.** Any direct internet request reveals it. WeatherGlass runs no
  proxy to mask it — a proxy would be a middleman that could log *more*, and it would
  break the keyless, no-backend design. The honest trade: reveal the IP, minimise
  everything around it (coarse location, aggressive caching so we ask rarely).
- **The place name you search.** A name lookup inherently sends the name. This is
  separate from the per-location forecast fingerprint; once a place is saved, viewing
  it uses only request #1.
- **The constellation.** The *set* of coarse cells requested from one IP over time is
  still loosely correlatable. Rounding and caching shrink that trail; they do not erase
  it. We do not claim they do.
- **Transport-layer identity.** TLS fingerprints (JA3/JA4) and the User-Agent are not
  under a browser app's control. They differ between the PWA (browser-generic) and the
  APK (Dart's own UA) — neither is a per-user identifier, and neither is something the
  app can change.

## How you can check all of this yourself

The point of WeatherGlass is that you don't have to take its word:

1. **In-app.** Open **Settings → What leaves your device**. It shows the *real* request
   URL for one of your saved places, the never-sent list, and the IP caveat verbatim.
2. **In the test suite.** [`open_meteo_client_test.dart`](../test/features/weather/open_meteo_client_test.dart)
   fails if any identifier ever creeps into the request. Run
   `flutter test test/features/weather/`.
3. **In the network tab.** Run the PWA, open your browser's DevTools → Network, add a
   place and watch the two requests above — those are the only ones.
4. **In the source.** [`open_meteo_client.dart`](../lib/features/weather/data/open_meteo_client.dart)
   is ~110 lines; the request is assembled in one place.

See [limitations.md](limitations.md) for the non-privacy things WeatherGlass
deliberately does not do.
