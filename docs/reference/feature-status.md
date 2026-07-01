# Feature status

What's shipped, what's held out of scope, as of **v0.1.0**. For the honest privacy
ceiling, see [privacy-model.md](../privacy-model.md); for the deliberate boundaries,
[limitations.md](../limitations.md).

## Shipped and tested

| Area | Status | Where |
|---|---|---|
| Coordinate rounding at add + send boundaries | ✅ tested | `domain/geo.dart`, `data/weather_repository.dart` |
| Fixed keyless request (fingerprint-free) | ✅ tested | `data/open_meteo_client.dart` |
| Location precision setting (coarse/balanced/precise) | ✅ | `domain/geo.dart`, privacy screen |
| Open-Meteo forecast + geocoding client | ✅ tested (parse) | `data/open_meteo_client.dart`, `data/models.dart` |
| WMO code → condition + icon | ✅ tested | `domain/weather_code.dart` |
| Current + 24 h hourly + 7-day daily | ✅ | `presentation/forecast_view.dart` |
| Living-sky hero (pure, deterministic) | ✅ tested + goldens | `domain/sky.dart` |
| Multiple saved places + reorder | ✅ | `data/locations_repository.dart`, `presentation/*` |
| "Use my location" (low-accuracy, rounded) | ✅ | `data/geolocation_service.dart` |
| 30-min forecast cache + self-heal eviction | ✅ tested | `data/weather_repository.dart` |
| Units (metric/imperial, client-side convert) | ✅ tested | `domain/units.dart` |
| "What leaves your device" transparency screen | ✅ | `presentation/privacy_screen.dart` |
| Encrypted backup/restore (saved places + settings, `.ohbk`) | ✅ tested | `features/sanctuary_backup/`, [how-to](../how-to/encrypted-backup.md) |
| Bundled fonts, no third-party egress | ✅ regression-tested | `pubspec.yaml`, `test/shared/theme/offline_fonts_test.dart` |
| Light/dark theme | ✅ | `settings_controller.dart` |
| PWA (offline, persisted storage) | ✅ shipped | `web/` |
| Sideload APK | ✅ shipped | `v0-apk` release |

## Deliberately out of scope

Not a roadmap — these are boundaries (each needs a second source and/or push, which
fights the keyless, no-backend design). See [limitations](../limitations.md).

| Not doing | Why |
|---|---|
| Severe-weather alerts | Need identifying/push channels |
| Radar / precipitation maps | Different data (tiles), different sources |
| Home-screen widget / notifications | No background wake-ups |
| Historical / climate archive | 7-day forecast window only |
| iOS release | Only PWA + APK are built |
| Cross-device sync | None today; if ever, encrypted-blob-relay only — not built |

## Known-honest limits (real, not solved)

- **IP is visible** on any direct request (no proxy, by design — [ADR-0004](../adr/0004-no-backend-direct-request.md)).
- **Search text** (place name) is sent to the geocoder.
- **Constellation correlation** of saved cells from one IP over time is shrunk, not
  erased.

## Testing

~75 tests across `test/` — domain (`geo`, `sky`, `weather_code`, `units`), data
(`forecast_parse`, `open_meteo_client`, cache poison, relocate), core (failures,
provider keep-alive), encrypted backup (serializer round-trip + schema/app rejection,
controller flow against the real crypto core, settings widget + 320dp×3.0 textScale),
plus golden images for the forecast view. No end-to-end network integration test; live
behavior verified manually (`DECISIONS.md`).
