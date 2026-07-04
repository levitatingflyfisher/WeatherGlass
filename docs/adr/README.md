# Architecture Decision Records

Load-bearing decisions, in the lightweight [Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
format (**Status · Context · Decision · Consequences**). These record the choices a
future maintainer would otherwise re-litigate. The fuller design narrative lives in
[DECISIONS.md](../../DECISIONS.md); these formalize the parts that must not drift.

| ADR | Decision |
|---|---|
| [0001](0001-openhearth-flutter-stack.md) | Adopt the OpenHearth Flutter stack — Clean Architecture, Riverpod, Drift, local-first, no accounts |
| [0002](0002-open-meteo-only.md) | Use Open-Meteo as the only data source (keyless, CORS, CC BY 4.0) |
| [0003](0003-coordinate-rounding-privacy-lever.md) | Coordinate rounding at the boundary is the privacy lever |
| [0004](0004-no-backend-direct-request.md) | No backend — call the provider directly, and be honest about the IP |
| [0005](0005-no-third-party-egress.md) | No third-party runtime egress — bundle assets, no analytics |
| [0006](0006-dual-pwa-apk-target.md) | Ship as a PWA and a sideload APK |
