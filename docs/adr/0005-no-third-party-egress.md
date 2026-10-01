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

- **Bundle fonts.** Lora and Nunito ship as assets in the APK/PWA, declared as package
  fonts by the shared `openhearth_design` dependency (the app declared its own copies
  until the 2026-09 fleet font migration); nothing is fetched from Google at runtime. (A regression test guards
  that the Google Fonts path is gone.)
- **No analytics, telemetry, crash reporting, or ad SDK** — none is added, so there is
  nothing to disable.
- Icons use a bundled icon font (`lucide_flutter`); no remote icon or tile fetch.
- **Serve the web engine from the app.** A default Flutter web build fetches CanvasKit
  from `www.gstatic.com` and a Roboto fallback font from `fonts.gstatic.com` on every
  load, and the PWA did both until 2026-10 despite the bundled fonts above.
  `web/flutter_bootstrap.js` now points `canvasKitBaseUrl` and `fontFallbackBaseUrl`
  at the app's own origin: CanvasKit at the build's own copy, fallback fonts at
  `/fonts/flutter-fallback/`, the fleet's one copy of the engine's Noto fallback
  set, mirrored by the user site at the same origin (levitatingflyfisher.github.io).
  Text is drawn from the bundled fonts; a glyph they lack (a typed place name with
  ř or ł, an emoji) is fetched from that copy on first draw, never from Google.
  Roboto 404s there by design. The PWA is built with
  `--no-web-resources-cdn`. Conformance C13 fails if the bootstrap loses that config.
  The request URLs on "What leaves your device" use `OhTypography.code()`, which is the
  bundled Nunito on the web: the platform `monospace` they once asked for drew as
  nothing there once Roboto was gone.

## Consequences

- Launch and render touch no server; the first network call is a weather/geocode request
  the user initiated.
- Slightly larger install (bundled fonts) in exchange for zero font-CDN egress — the
  right trade for a privacy app.
- Any future dependency that phones home at runtime is a regression against this ADR and
  must be rejected or sandboxed. Treat "harmless CDN fetch" as a privacy change.
- Reinforces that the "What leaves your device" screen is *complete*: the two Open-Meteo
  requests really are the whole story.
