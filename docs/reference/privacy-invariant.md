# The privacy invariant — a precise specification

*The coordinate-rounding rule and the fixed-request rule: stated rigorously, with
the tests that enforce them.*

**Register.** This is the closest thing WeatherGlass has to a formal specification.
It is precise about *intent and current behavior*; it is **not** a machine-checked
proof. The code it describes was authored by an AI assistant — treat it as the
current implementation to be checked against this spec, not as an oracle. Where a
property is enforced by a test rather than proven, it says which test. For the
intuition first, read [concepts.md](../concepts.md) and
[privacy-model.md](../privacy-model.md).

The whole privacy claim reduces to two invariants:

- **I1 (Rounding).** No coordinate finer than the user's chosen precision is ever
  persisted or sent.
- **I2 (Fixed request).** A forecast request carries a fixed, identifier-free set of
  parameters plus the rounded coordinates — and nothing else.

If both hold, the provider learns only *a coarse grid cell* and *your IP*, and it
cannot tell two of your requests apart from two strangers' by anything in the request
itself.

---

## 1. Notation

A location is a pair `(φ, λ)` of decimal degrees — latitude `φ`, longitude `λ`. A
**precision** `p` is one of three levels, each fixing a number of decimal places `d(p)`:

| precision | `d(p)` | grid step `ε = 10⁻ᵈ` | equator cell width |
|---|---|---|---|
| `coarse`   | 1 | 0.1°  | ~11 km  |
| `balanced` (default) | 2 | 0.01° | ~1 km  |
| `precise`  | 3 | 0.001° | ~110 m |

(Source of truth: the `LocationPrecision` enum in
[`domain/geo.dart`](../../lib/features/weather/domain/geo.dart).)

## 2. The rounding function

```
roundCoord(x, d)  =  round(x · 10ᵈ) / 10ᵈ            (round: half away from zero)
roundForPrecision(φ, λ, p)  =  ( roundCoord(φ, d(p)), roundCoord(λ, d(p)) )
```

`roundCoord` snaps a coordinate to the nearest multiple of `ε = 10⁻ᵈ`. Therefore the
stored value differs from the true value by **at most half a grid step** on each axis:

```
| roundCoord(x, d) − x |  ≤  ε / 2  =  ½ · 10⁻ᵈ    degrees
```

### 2.1 Why this bounds locational precision

Ground distance per degree of latitude is ≈ 111.32 km (nearly constant). Per degree
of longitude it is ≈ 111.32 · cos φ km — it *shrinks* toward the poles. So the
worst-case ground displacement introduced by rounding is:

```
north–south:  ≤ (ε/2) · 111.32 km
east–west:    ≤ (ε/2) · 111.32 · cos φ km   ≤ (ε/2) · 111.32 km
```

The equator numbers in §1 are therefore **upper bounds**: at any latitude away from
the equator the east–west blur is *tighter*, so a given decimal hides at least as
much ground as advertised, never less. Rounding maps the continuous plane onto a grid
of cells of width `ε`; the provider sees which cell, not where in it.

### 2.2 Monotonicity (coarser never reveals more)

Each additional decimal multiplies the number of distinguishable grid values per
degree by ten, per axis. Going from `precise` (d=3) to `coarse` (d=1) drops two
decimals — 10² fewer cells per axis, ~10⁴ larger cell area. Formally the guarantee is
one-directional and is all the app relies on:

> **(Monotonicity, tested.)** `d(coarse) < d(balanced) < d(precise)`, and a coarser
> precision yields a value with no more significant decimal places than a finer one.
> Enforced by `geo_test.dart` ("coarser precision can never reveal more than finer").

## 3. Where I1 is enforced — the two boundaries

A coordinate must be rounded at **every** point where it could be stored or sent.
There are exactly two such boundaries, and both call `roundForPrecision`:

1. **Add boundary** — `_addPlace` / `_locateMe` in
   [`add_location_sheet.dart`](../../lib/features/weather/presentation/add_location_sheet.dart)
   round *before* handing the coordinate to `LocationsRepository`. The Drift
   `SavedLocations` table therefore only ever holds a rounded value: even a full
   device dump leaks only a coarse cell.
2. **Send boundary** — `getForecast` in
   [`weather_repository.dart`](../../lib/features/weather/data/weather_repository.dart)
   re-rounds the stored coordinate to the **current** precision before building the
   request. This is the subtle, load-bearing one: if a user saves a place at
   `precise` and later switches to `coarse`, the saved row keeps its finer grid — and
   without re-rounding, every request would leak it. Re-rounding at send makes the
   precision setting authoritative for all outbound traffic regardless of when the
   place was saved. The `forecast` provider watches the precision setting so a change
   actually recomputes and refetches.

**Corollary.** The device-location fix is requested at `LocationAccuracy.low`
([`geolocation_service.dart`](../../lib/features/weather/data/geolocation_service.dart))
and then rounded again — a coarse fix, coarsened.

## 4. The fixed-request invariant (I2)

`OpenMeteo.forecastUrl(lat, lon)` in
[`open_meteo_client.dart`](../../lib/features/weather/data/open_meteo_client.dart)
builds an HTTPS request to `api.open-meteo.com/v1/forecast` whose query is exactly:

```
latitude, longitude          ← the only values that vary between requests
current, hourly, daily       ← fixed field lists (always request metric)
timezone = auto
forecast_days = 7
```

The invariant, precisely:

- **(I2a) Exact key set.** `queryParameters.keys == {latitude, longitude, current,
  hourly, daily, timezone, forecast_days}`. No other key may appear.
- **(I2b) Only coordinates vary.** For any two locations, the request is
  byte-identical after removing `latitude`/`longitude`.
- **(I2c) No identifier of any known shape.** None of `apikey, api_key, key, appid,
  token, access_token, uid, user, user_id, client_id, install_id, device_id, session,
  sid, nonce, cb, _, t, ts, timestamp, rand` may appear; the URL has no `userInfo` and
  no `fragment`.
- **(I2d) Units never touch the URL.** Metric is always requested; the user's unit
  preference is applied client-side ([`units.dart`](../../lib/features/weather/domain/units.dart)),
  so it cannot become a fingerprint.

## 5. How the tests enforce it

| Invariant | Test | What it asserts |
|---|---|---|
| I1 rounding correctness | `geo_test.dart` → `roundCoord` | Half-away-from-zero rounding to d decimals, incl. negatives |
| I1 per-precision | `geo_test.dart` → `roundForPrecision` | `balanced`→2dp, `coarse`→1dp, `precise`→3dp on real coordinates |
| I1 monotonicity | `geo_test.dart` | Coarser precision has strictly fewer decimals; values differ |
| I1 safe default | `geo_test.dart` | `LocationPrecision.fromName` falls back to `balanced` on unknown/null |
| I2a/I2b | `open_meteo_client_test.dart` → "carries EXACTLY the fixed params" / "only those vary" | Exact key set; coordinate-only variation |
| I2c | `open_meteo_client_test.dart` → "no key / token / cache-buster of any known shape" | The banned-key list; no userInfo/fragment |
| endpoint | `open_meteo_client_test.dart` | Scheme `https`, keyless host + path for forecast and geocoding |

These pass in the current tree (`flutter test test/features/weather/`). The comment
atop `open_meteo_client_test.dart` states the contract in one line: *"If anyone ever
adds such a parameter, this test must fail."* Treat a new query parameter as a privacy
change requiring review, not a feature.

## 6. Fail-safe behavior

- **Unknown precision string ⇒ `balanced`.** A corrupt or missing stored preference
  resolves to the middle setting, never to `precise`
  ([`geo.dart` `fromName`](../../lib/features/weather/domain/geo.dart)).
- **Send-boundary re-round is unconditional.** It does not depend on the row being
  saved at the same precision; it always applies the current setting before a request.
- **The cache cannot leak more than a request already did.** The cache is keyed by
  `locationId` and stores the raw response of a request that was *itself* built from a
  rounded coordinate; serving it makes no new network call. (A row fetched earlier at
  a finer precision is served from disk until its 30-minute TTL expires; the next
  *network* request re-rounds. No new outbound leak occurs.)

## 7. What this invariant does NOT cover

The invariant is sound *for what it checks*. It bounds the **precision and shape** of
what a forecast request contains. It does not, and cannot, cover:

- **Your IP.** Any direct request reveals it; WeatherGlass runs no proxy and says so
  ([privacy-model.md](../privacy-model.md), [ADR-0004](../adr/0004-no-backend-direct-request.md)).
- **Search text.** A place *name* typed into search is sent verbatim to the geocoder —
  inherent to a name lookup, and separate from the per-location forecast fingerprint.
- **The constellation.** The *set* of coarse cells one IP requests over time is still
  loosely correlatable; rounding + caching shrink it, they do not erase it.
- **Transport-layer identity.** TLS fingerprints (JA3/JA4) and the User-Agent are not
  under a browser app's control; they differ between the PWA (browser-generic) and the
  APK (Dart's UA) but are not per-user identifiers.

These are stated honestly in [privacy-model.md](../privacy-model.md) and on the
in-app "What leaves your device" screen. The claim WeatherGlass makes is exactly the
one these two invariants support — no more.

---

*This specification describes the current implementation as authored by an AI
assistant. A discrepancy between this document and the code is a bug in one or the
other — check it against the tests before relying on any stated property.*
