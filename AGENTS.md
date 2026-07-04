# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. This is the
top-level map; when a rule here and a rule in a nested file disagree, the closest
file to what you're editing wins.

**Read these, in order, before non-trivial work:**
1. [VISION.md](VISION.md) — what must stay true and why (the invariants).
2. [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) — how it fits together, with a diagram.
3. [docs/reference/privacy-invariant.md](docs/reference/privacy-invariant.md) — the one rule you can most easily break by accident.

## Take the code as current-state, not gospel

Every line of source and every comment here was written by an AI assistant. Treat it
as **an accurate record of what currently exists, offered with gratitude and a grain
of salt** — not as a specification and not as guaranteed-correct. A comment claiming
an invariant is a *hypothesis to verify*, not a proof. If a comment and the tests
disagree, the tests win; if the tests and reality disagree, reality wins. When you
rely on a claim, confirm it (read the code, run the test) first.

## What this is

A calm, local-first **weather** app for the household (Flutter; PWA + sideload APK).
Current conditions, hourly, and 7-day for the places you save — on a screen painted
from the real sky. It is a privacy-respecting app: the whole point is to read the
weather without handing a tracker your location. Data comes from **Open-Meteo only**
(keyless, CORS-friendly, CC BY 4.0). Clean Architecture, Riverpod, Drift. ~50 tests.

## Non-negotiables (breaking one is a regression, not a feature)

- **Round before it leaves.** Coordinates are coarsened at the boundary (on add /
  locate) *and* re-rounded to the current precision at the send boundary. Never
  persist or send a finer coordinate than the user's precision setting allows. If you
  add a code path that reaches the network with a location, it rounds first.
- **The request stays fingerprint-free.** `OpenMeteo.forecastUrl` carries a fixed
  param set + the rounded coords and nothing else — no key, token, cache-buster, or
  custom header. [`open_meteo_client_test.dart`](test/features/weather/open_meteo_client_test.dart)
  pins this; a new query parameter must make that test fail. Treat it as a privacy
  change, not a feature.
- **One source, keyless.** Open-Meteo only. No second provider that needs a key, a
  proxy, or an identifying User-Agent (that is why MET Norway / NWS were rejected —
  see [ADR-0002](docs/adr/0002-open-meteo-only.md)).
- **No third-party runtime egress.** No analytics, no ad SDK, no fonts or assets
  fetched at runtime from a third party (fonts are bundled). No backend of ours.
- **Units never touch the URL.** Always request metric; convert for display client-
  side. The unit preference must not alter the request shape.
- **TDD, always.** Reproduce → failing test → fix → `flutter test` green → commit.
  Every bugfix ships with a regression test. Domain logic (`geo`, `sky`,
  `weather_code`, `units`) is pure and must stay unit-tested.
- **Atomic commits, one concern each.** Commit messages state the *why* and the
  failure mode fixed. **No AI-attribution trailers** in commit messages — deliberate
  project policy.
- **Never commit** local assistant working-notes (`GEMINI.md` and the other gitignored
  per-tool agent-memory files) or `docs/superpowers/` — they're working artifacts. This
  repo ships `AGENTS.md`.

## Where things are (progressive disclosure)

Feature-first Clean Architecture under `lib/`. Start with the module map in
[OVERVIEW.md § Module map](docs/architecture/OVERVIEW.md#module-map--where-to-look).
The short version, by concern:

| You're touching… | Go to |
|---|---|
| **The privacy lever** (rounding / precision) | `features/weather/domain/geo.dart`, and every call site of `roundForPrecision` (`add_location_sheet.dart`, `weather_repository.dart`) |
| **The outbound request** (must stay keyless) | `features/weather/data/open_meteo_client.dart` |
| **Fetching + caching** | `features/weather/data/weather_repository.dart` (30-min TTL, self-healing evict) |
| **Local storage** (places, cache) | `core/storage/app_database.dart` (Drift tables), `features/weather/data/locations_repository.dart` |
| **The forecast data model / JSON parse** | `features/weather/data/models.dart` |
| **Domain logic (pure, TDD'd)** | `domain/geo.dart` · `domain/weather_code.dart` (WMO→condition) · `domain/sky.dart` (living-sky palette) · `domain/units.dart` |
| **The transparency screen** | `features/settings/presentation/privacy_screen.dart` |
| **Settings** (units / precision / theme) | `features/settings/settings_controller.dart`, `features/settings/domain/settings.dart` |
| **Screens & navigation** | `features/weather/presentation/*` (home, forecast, locations, add-sheet), `core/router/app_router.dart` |
| **State wiring** | `core/providers/core_providers.dart` (Riverpod codegen providers) |

Docs are organized [Diátaxis](https://diataxis.fr/)-style — see
[docs/README.md](docs/README.md) for the tutorials / how-to / reference / explanation
split.

## How to work here

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # codegen: *.g.dart are gitignored, regenerate after checkout/dep changes
flutter test        # the suite — must be green before you commit
flutter analyze     # static analysis — must be zero issues
dart format .       # formatting
flutter run -d chrome                                       # dev (web)
flutter build web --base-href "/WeatherGlass/"             # PWA build
flutter build apk --split-per-abi --release                # APK build
```

- Flutter/Dart, SDK `>=3.3.0`. Generated `*.g.dart` (Drift + Riverpod) are gitignored
  — a fresh checkout **must** run `build_runner` before `flutter build`, or you get
  "No such file or directory" on `*.g.dart` imports.
- Repository tests use an in-memory SQLite DB (`AppDatabase(NativeDatabase.memory())`)
  — no mocking needed. Widget/golden tests live in `test/visual/`; a `CustomPainter`'s
  `TextPainter` renders as tofu in headless goldens but fine live (see `DECISIONS.md`).
- The full decision history and design notes are in [DECISIONS.md](DECISIONS.md);
  the formalized load-bearing choices are in [docs/adr/](docs/adr/).

## When you're unsure

Prefer the more private default to the more convenient one. Prefer a failing test to
a plausible fix. Prefer matching the surrounding code to introducing a new pattern.
On anything that touches the path a location takes to the network, prefer asking (or
leaving a `TODO` with the open question) to guessing. When in doubt about a decision's
rationale, read [docs/adr/](docs/adr/) before reopening it — you may be re-litigating
a settled trade-off.
