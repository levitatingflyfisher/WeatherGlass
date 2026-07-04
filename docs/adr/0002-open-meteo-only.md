# ADR-0002 — Open-Meteo as the only data source

**Status:** Accepted (from deep research at design time).

## Context

A weather app needs a forecast source and a geocoder (name → coordinates). The privacy
goal (ADR-0003, ADR-0004) requires a source a **pure browser app can call directly** —
no API key that identifies the install, no proxy, no cookies. The candidates:

- **Open-Meteo** — genuinely FLOSS (server AGPLv3, data CC BY 4.0), **no API key**,
  **wildcard CORS** (callable from a browser with no backend), no cookies, near-global
  via ~15 aggregated national models (~11 km, ~1.5 km regionally). Free tier is
  non-commercial. Sibling keyless geocoder at `geocoding-api.open-meteo.com`.
- **MET Norway**, **US NWS** — high quality, but both **mandate an identifying
  `User-Agent`** that a browser silently drops (Chrome ignores a JS-set UA). Using them
  from a browser forces a proxy.

## Decision

Use **Open-Meteo, and only Open-Meteo**, for both forecast and geocoding. No second
provider and no fallback source. Attribution ("Weather data by Open-Meteo.com", CC BY
4.0) is shown on the forecast and the privacy screen.

## Consequences

- A pure browser PWA works with **no backend** — the enabling condition for ADR-0004.
- **No fallback:** if Open-Meteo is unavailable, forecasts fail; there is no second
  source. Accepted as the cost of the keyless, no-proxy stance (see
  [limitations](../limitations.md)).
- MET Norway / NWS are rejected specifically because their UA requirement would force a
  proxy and reintroduce a middleman. Open-Meteo already aggregates DWD/MET data, so
  little coverage is lost.
- The non-commercial free tier suits a no-ads family app but is not licensed for
  commercial redistribution.
- Coverage is aggregated-model quality — excellent generally, occasionally less sharp
  than a national service for severe local weather.
