# ADR-0006 — Ship as a PWA and a sideload APK

**Status:** Accepted (fleet convention, shared with Furrow/Sundial).

## Context

WeatherGlass should reach households without asking them to trust an app store account
or a proprietary distribution channel, and without a backend to host. Open-Meteo's
wildcard CORS (ADR-0002) means the app runs fully in a browser with no server, which
makes a Progressive Web App a first-class target. A sideload APK covers Android users who
want a real installed app and offline device storage without going through a store.

## Decision

Ship two artifacts from one Flutter codebase:

- **PWA** → GitHub Pages, built with `flutter build web --base-href "/WeatherGlass/"`.
  The boot spinner, service-worker self-heal, and `navigator.storage.persist()` call are
  baked into the source `web/index.html` (not re-spliced on each deploy).
- **Sideload APK** → `flutter build apk --split-per-abi --release`, published on a
  `v0-apk` release, with a landing card on the OpenHearth GitHub Pages site.

No iOS build is published; no app-store distribution.

## Consequences

- Users can run WeatherGlass with zero install (web) or sideload the APK — no store
  account either way.
- The PWA and APK differ at the transport layer (browser-generic UA vs. Dart's UA); both
  are documented as non-per-user-trackable (see [privacy-model](../privacy-model.md)).
- Drift-on-web requires the sqlite3 WASM engine + drift worker in `web/`, and persisted
  storage requires the explicit `navigator.storage.persist()` call to survive eviction.
- Two build/deploy paths to keep working; see
  [how-to/deploy-pwa-and-apk.md](../how-to/deploy-pwa-and-apk.md).
- iOS remains unbuilt; adopting it later means a new signing/distribution story.
