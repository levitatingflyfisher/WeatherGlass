# Changelog

All notable changes to WeatherGlass will be documented in this file.

## [Unreleased]

### Added
- Snapshot vault ("Previous backups" in Settings → Backup & Restore):
  every encrypted export and every restore leaves a stamped on-device
  snapshot (keep-10, pinnable) you can restore, pin or delete.
- Mandatory pre-restore snapshot: a restore refuses to run unless the
  current places + settings were snapshotted (and the snapshot verified
  by read-back) first — restoring is now reversible.
- Preview before restore: the confirm dialog shows the backup's age and
  saved-place counts next to what's on the device now, validated by
  WeatherGlass's own restore gate (wrong app / future schema / missing
  tables or settings are rejected at preview time, not mid-restore).
- "Export as plain JSON": an honest, unencrypted copy of your places and
  settings any program can read.
- Encrypted exports verify themselves by read-back before reporting
  success, and the backup envelope now carries a `createdAt` stamp
  ADDITIVELY (older backups still restore; older app versions still
  read new backups — no legacy key was removed or renamed).
- Silent freshness snapshot on app open when the newest one is older
  than 7 days (never blocks boot, never surfaces errors).
- `DateTime` helpers synced to the fleet superset (additive only):
  `dateOnly`, `startOfWeek`, DST-safe `daysBetweenDates`, and
  `minutesToLabel`. Existing helpers and callers untouched.
- Fleet conformance suite (`test/fleet_conformance_test.dart` on
  `oh_fleet_conformance`): design-token single-source, backup adoption,
  size budgets (`budgets.json` ratchet), the exact
  INTERNET + ACCESS_COARSE_LOCATION permission surface, and harness
  canon are now failing-able tests.
- Push/PR CI workflow (analyze + tests + debug-APK and web-release
  smoke builds on the fleet-pinned Flutter 3.38.7). The release
  workflow now also clones the ohStyle and ohFleetConformance sibling
  path deps it always needed.

### Changed
- Backup/restore now rides `sanctuary_backup_ui` 0.2.0.
- Goldens now render the app's bundled fonts: the fleet-canonical
  FontManifest-aware `flutter_test_config.dart` loads the Lucide icon
  font (and Lora/Nunito) in tests, so condition/metric icons appear as
  real glyphs instead of placeholder boxes. Test-only; no app change.
- The Material-scale Lora/Nunito text ladder now comes from the shared
  `openhearth_design` package (`OhTypography.materialTextTheme`) instead
  of a hand-rolled copy — byte-identical by construction, pinned by an
  identity test and the golden suite. Zero visual change.

### Removed
- Unused direct `share_plus` dependency (the backup share flow lives in
  `sanctuary_backup_ui`, which declares its own).
