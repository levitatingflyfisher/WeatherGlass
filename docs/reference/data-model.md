# Data model reference

Exact shapes: what's stored on the device, the in-memory domain types, and how an
Open-Meteo response maps onto them. Source of truth is the code; this is the map.

## Stored — Drift tables (schema v1)

Database `glass` ([`core/storage/app_database.dart`](../../lib/core/storage/app_database.dart)),
native SQLite on mobile, WASM on web.

### `SavedLocations` — the places you watch

| Column | Type | Notes |
|---|---|---|
| `id` | text (PK) | UUID v4 |
| `label` | text | e.g. "Berlin" |
| `sublabel` | text? | e.g. "State of Berlin, Germany" |
| `lat` | real | **stored already rounded** to the user's precision |
| `lon` | real | **stored already rounded** |
| `isCurrent` | bool | the single "My location" entry, re-resolved on demand |
| `sortOrder` | int | display order |
| `createdAt` | int | epoch ms |

The rounding of `lat`/`lon` before insert is the [privacy invariant](privacy-invariant.md)
at the storage boundary.

### `ForecastCache` — one cached forecast per place

| Column | Type | Notes |
|---|---|---|
| `locationId` | text (PK) | FK-by-convention to `SavedLocations.id` |
| `payload` | text | the **raw** Open-Meteo JSON, cached verbatim |
| `fetchedAt` | int | epoch ms; freshness compared against the 30-min TTL |

Removing a location deletes its cache row; re-resolving "My location" invalidates its
cache. A row that fails to parse is evicted and refetched (self-heal).

## Settings (SharedPreferences, not Drift)

[`features/settings/domain/settings.dart`](../../lib/features/settings/domain/settings.dart) —
`GlassSettings { units, precision, themeMode }`. Defaults: `metric`, `balanced`
(~1 km), `system`. None of these alter the request shape.

## In-memory domain types

[`features/weather/data/models.dart`](../../lib/features/weather/data/models.dart):

| Type | Fields (all temps °C internally) |
|---|---|
| `GeoPlace` | `name, latitude, longitude, admin1?, country?, countryCode?` — the **raw** geocoder result (rounded before it's persisted); `region` joins admin1+country |
| `CurrentConditions` | `time, temperatureC, apparentC, weatherCode, isDay, windKmh, humidity, precipMm`; `condition` derives from `weatherCode` |
| `HourlyPoint` | `time, temperatureC, precipProbability, weatherCode` |
| `DailyPoint` | `date, weatherCode, highC, lowC, precipProbabilityMax, sunrise?, sunset?` |
| `Forecast` | `current, hourly[], daily[], utcOffsetSeconds` |

Temperatures are stored and reasoned about in **Celsius**; conversion to the display
unit happens at the edge ([`units.dart`](../../lib/features/weather/domain/units.dart)),
never in the request.

## Open-Meteo response → `Forecast`

`Forecast.fromJson` parses the `/v1/forecast` response, whose hourly/daily sections are
**parallel arrays** (a `time` list plus one list per variable, index-aligned):

| Response path | Maps to |
|---|---|
| `current.{time, temperature_2m, apparent_temperature, weather_code, is_day, wind_speed_10m, relative_humidity_2m, precipitation}` | `CurrentConditions` |
| `hourly.{time[], temperature_2m[], precipitation_probability[], weather_code[]}` | `List<HourlyPoint>` (168 points ≈ 7 days) |
| `daily.{time[], weather_code[], temperature_2m_max[], temperature_2m_min[], precipitation_probability_max[], sunrise[], sunset[]}` | `List<DailyPoint>` (7 days) |
| `utc_offset_seconds` | `Forecast.utcOffsetSeconds` |

Because the request sends `timezone=auto`, times are the **location's local wall clock**
and are parsed naively — shown as-is, never timezone-shifted. `weather_code` is a WMO
code; see [concepts § weather condition](../concepts.md#weather-condition-wmo-codes).
The exact request that produces this response is specified in
[privacy-invariant § I2](privacy-invariant.md#4-the-fixed-request-invariant-i2).
