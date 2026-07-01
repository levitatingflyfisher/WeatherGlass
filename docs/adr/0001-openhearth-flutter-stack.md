# ADR-0001 — Adopt the OpenHearth Flutter stack

**Status:** Accepted (forked from Furrow at project start).

## Context

WeatherGlass is one app in the OpenHearth family of small, private, local-first tools.
The family already has a proven Flutter stack (Furrow, Sundial), and consistency across
apps lowers the cost of maintaining all of them. The app needs on-device storage for
saved places and a forecast cache, reactive state for a screen that redraws as the sky
changes, and a clean seam between pure logic (rounding, condition mapping) and the UI so
that logic can be tested in isolation.

## Decision

Build on the OpenHearth Flutter stack, forked from Furrow:

- **Flutter**, feature-first **Clean Architecture** — each feature owns `domain`
  (pure, no Flutter), `data` (repositories, client, storage), and `presentation`;
  shared plumbing under `lib/core` and `lib/shared`.
- **Riverpod** (code-generated providers) for state and dependency wiring.
- **Drift** over SQLite for local storage (native on mobile, WASM on web).
- **Local-first, no accounts:** all data on-device; no sign-in, no cloud, no server.

## Consequences

- Domain logic (`geo`, `sky`, `weather_code`, `units`) is pure and unit-tested; the
  privacy invariant lives in `geo.dart` where it can be tested without a UI or a network.
- Repository tests use an in-memory SQLite database — no mocking.
- Generated `*.g.dart` files (Drift, Riverpod) are gitignored; a fresh clone must run
  `build_runner` before it builds. This trips up newcomers and is documented in
  [how-to/build-and-run.md](../how-to/build-and-run.md) and `CONTRIBUTING.md`.
- Drift on web needs the sqlite3 WASM engine and drift worker shipped in `web/` and
  pointed at explicitly, or startup throws.
- "No accounts" is a feature, not a gap: there is no server-side profile to leak, which
  is what makes the privacy story (ADR-0003, ADR-0004) hold by construction.
