# Vision

> The north star for WeatherGlass. If you (person or agent) are about to change
> something load-bearing — especially anything on the path a location takes to the
> network — read this first. It says what must stay true and why.
> For *how it's built*, see [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md);
> for *why each decision was made*, [docs/adr/](docs/adr/); for the privacy rule
> stated precisely, [docs/reference/privacy-invariant.md](docs/reference/privacy-invariant.md).

## The one idea

**You can read the sky without telling anyone where you are.**

Every mainstream weather app is a location-tracking business with a forecast
attached: an account, an API key that is really a per-install identifier, an
analytics SDK, and your exact coordinates sent to a server that has every reason to
remember them. The forecast is the bait; the location trail is the product.

WeatherGlass inverts that. The forecast is the whole product, and the location is
treated as something to reveal as *little* of as possible. The move that makes this
work is small and concrete:

> **Blur the coordinate before it leaves the device, use the one open, keyless
> weather source, and show the user the exact request so they can check the claim.**

You cannot make a direct internet request invisible — the provider always sees your
IP. But you *can* control the two things a browser app actually holds: how precise a
location it sends, and how often it asks. So WeatherGlass rounds every coordinate to
a coarse grid cell *before* anything is stored or sent, pins the request to a fixed,
keyless, identifier-free shape, and puts the real URL on a screen you can read.

## What this is

A calm, **local-first** weather app for the household — current conditions, the next
hours, and the week ahead for the places you care about, on a screen painted from the
real sky. Part of the **OpenHearth** family of small, private, open-source tools for
domestic life. Built in Flutter; ships as a PWA and a sideload APK.

```
  a place you add            WeatherGlass                     the network
 ─────────────────       ──────────────────────         ──────────────────────
  "Berlin" / locate-me ─▶  round to a grid cell   ──▶    Open-Meteo (keyless,
  (exact coordinate)       (before store OR send)        CORS, CC-BY) sees only
                           fixed keyless request         a coarse cell + your IP
                           cache 30 min · living sky
```

## The invariants (do not break these)

These are the load-bearing beliefs. Breaking one is a design regression, not a
feature. Each is enforced in tests and/or recorded as an ADR.

1. **Local-first, not local-only.** Your places and forecast history live on the
   device (Drift/SQLite). There is **no account, no sign-in, no cloud** — core
   functionality is the whole app, not a tier. ([ADR-0001](docs/adr/0001-openhearth-flutter-stack.md))
2. **The coordinate is rounded before it leaves.** Rounding is the one privacy lever
   a browser app genuinely controls (it cannot touch TLS/JA3 or the User-Agent). A
   place is coarsened the moment it is added or located, only the coarse value is
   ever persisted, and every outbound request is re-rounded to the *current*
   precision at the send boundary. Precision is the user's choice: Coarse ~11 km /
   Balanced ~1 km (default) / Precise ~110 m.
   ([ADR-0003](docs/adr/0003-coordinate-rounding-privacy-lever.md), [the invariant](docs/reference/privacy-invariant.md))
3. **The request carries no identifier.** The forecast URL is a fixed parameter set
   plus the rounded coordinates — no API key, no per-install/per-user token, no
   cache-busting timestamp, no custom header. **This is pinned by a passing test**
   ([`open_meteo_client_test.dart`](test/features/weather/open_meteo_client_test.dart));
   treat any new query parameter as a privacy change, not a feature.
4. **One open, keyless source.** Weather and geocoding come from **Open-Meteo only** —
   the single genuinely FLOSS source (server AGPLv3, data CC BY 4.0), keyless,
   CORS-friendly, no cookies. Attribution is shown in-app.
   ([ADR-0002](docs/adr/0002-open-meteo-only.md))
5. **No backend, and honest about the IP.** WeatherGlass calls the provider directly
   from the device — no server of ours to mask your IP, and we **say so plainly** on
   the "What leaves your device" screen rather than pretending otherwise. We minimise
   everything else around a leak we can't erase. ([ADR-0004](docs/adr/0004-no-backend-direct-request.md))
6. **No ads, no trackers, no analytics** — architecturally, not just as a promise:
   there is no analytics SDK, no third-party runtime fetch (fonts are bundled, not
   pulled from Google), nothing to disable. ([ADR-0005](docs/adr/0005-no-third-party-egress.md))

## Honest scorecard — built vs. aspirational

A guiding light has to tell the truth about where the light reaches. This code and
its comments were written by an AI assistant; treat them as *an accurate record of
what currently exists, offered with gratitude and a grain of salt* — verify a claim
before you rely on it. As of v0.1.0:

**Real, tested, load-bearing:**
- The privacy spine: coordinate rounding at both the add boundary and the send
  boundary, and the fixed keyless request. This is the whole thesis, and it holds —
  `geo_test.dart` and `open_meteo_client_test.dart` enforce it and pass.
- The weather core: Open-Meteo client (forecast + geocoding), the parallel-array JSON
  parse, WMO-code → condition mapping, metric-request-then-convert units, and the
  30-minute cache with self-healing eviction of a poisoned row — all tested.
- The signature: `skyFor` — a pure, deterministic living-sky palette from condition +
  day/night — tested, and swept with golden images.
- The transparency screen shows the *real* request URL for a saved place, the
  never-sent list, and the honest IP caveat.
- Ships as a PWA (offline-capable, persisted storage) and a sideload APK.

**Aspirational — documented, or deliberately out of scope:**
- **Held-out scope** (a different app, not a TODO): severe-weather alerts, radar, and
  a home-screen widget. Adding them means a second data source and/or push — see
  [limitations](docs/limitations.md). We say no on purpose.
- **The correlation limit is real, not solved.** Rounding + caching shrink the trail;
  they do not erase it. The *constellation* of your saved places, seen from one IP
  over time, is still loosely correlatable. We shrink it honestly; we don't claim
  anonymity. ([privacy model](docs/privacy-model.md))
- **No sync.** By design there is no cross-device sync today. If it ever ships it
  must be encrypted-blob-through-a-dumb-relay, never a BaaS — but nothing is built.

The core is real. The privacy *claim* is precise and tested; the privacy *promise* is
deliberately modest. Keep that line bright.

## Horizons (problems, not a feature list)

Framed as problems, because for a privacy tool the honest open questions outlast any
dated feature list:

- **Near** — Shrink the search-text leak. A place *name* is inherently sent to the
  geocoder today (that is how a name lookup works); an on-device or offline gazetteer
  for common places would remove even that.
- **Mid** — The correlation problem stated in the scorecard: can the set of saved
  places seen from one IP be decorrelated without a proxy (request jitter, batching,
  decoy cells) *without* lying about what that buys? Only worth doing if it can be
  described honestly.
- **Far** — Multi-source coverage without betraying the no-backend rule. MET Norway
  and NWS give better local models but mandate an identifying User-Agent a browser
  can't send — which would force a proxy and re-introduce a middleman. The open
  question: richer data that still leaves no per-user fingerprint.

## The name

**WeatherGlass** — the household *weather-glass*, the barometer that used to hang by
the door: your own instrument, read at home, telling no one. It pairs with
**Sundial** in the OpenHearth fleet (two antique domestic instruments) and carries
the thesis in one word. It shipped first under the bare working name *Glass* — too
ambiguous — and was renamed to disambiguate while keeping the metaphor. The internal
Dart package id is still `glass` (invisible to users); the product is WeatherGlass.
