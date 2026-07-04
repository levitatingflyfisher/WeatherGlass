# ADR-0005 — No third-party runtime egress; bundle assets, no analytics

**Status:** Accepted (hardened after a Google Fonts egress was found and removed).

## Context

An app can leak the user to third parties without any explicit "tracking" feature. The
classic offenders are an analytics/crash SDK and **runtime-fetched fonts**: a common
Flutter pattern pulls web fonts from Google Fonts on first paint, which sends the user's
IP and a referer to Google every launch — quietly undoing the privacy posture the rest
of the app is built on. WeatherGlass was initially fetching Lora/Nunito that way.

## Decision

Permit **no third-party runtime egress**. The only network destination is Open-Meteo
(ADR-0002, ADR-0004).

- **Bundle fonts.** Lora and Nunito ship as assets in the APK/PWA and are declared in
  `pubspec.yaml`; nothing is fetched from Google at runtime. (A regression test guards
  that the Google Fonts path is gone.)
- **No analytics, telemetry, crash reporting, or ad SDK** — none is added, so there is
  nothing to disable.
- Icons use a bundled icon font (`lucide_flutter`); no remote icon or tile fetch.

## Consequences

- Launch and render touch no server; the first network call is a weather/geocode request
  the user initiated.
- Slightly larger install (bundled fonts) in exchange for zero font-CDN egress — the
  right trade for a privacy app.
- Any future dependency that phones home at runtime is a regression against this ADR and
  must be rejected or sandboxed. Treat "harmless CDN fetch" as a privacy change.
- Reinforces that the "What leaves your device" screen is *complete*: the two Open-Meteo
  requests really are the whole story.
