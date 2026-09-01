# Changelog

All notable changes to WeatherGlass will be documented in this file.

## [Unreleased]

### Changed (fleet-fix rollout, 2026-09)
- Adopts openhearth_design 0.7.2, sanctuary_backup_ui 0.3.0 and
  oh_fleet_conformance 0.8.1. The type ladder moved (body 14 → 16), and the
  goldens now render the app's real theme so such moves are visible.
- Lora and Nunito come from openhearth_design's package fonts; the app's own
  copies and `assets/fonts/OFL.txt` are gone (the licence ships with the
  package's faces).
- Errors on screen are OhErrorState (plain words, Try again, details behind a
  tap); offline, the last good forecast is shown with its age instead.
- Removing a place happens at once with an Undo that never expires (no
  dialog); the reorder handle moved away from the trash button.
- Theme is light / dark / follow phone, one tap from Home; the stored
  `themeMode` strings are unchanged.
- Wide screens: each screen caps its own content (640 dp; the privacy screen
  560 dp) and Home's sky stays full-bleed, replacing the 760 px app box.
- Home's controls read Places and Settings; Places' + reads Add.
- The Backup section draws its own heading in every state, adds Show my
  recovery words, stores words only on consent, and a Finish-setup reminder
  sits at the top of Settings. Web key storage is scoped to this app.
- Section labels are sentence case headings; the hourly graph follows text
  size and uses the app's type; all text on the sky reaches 4.5:1.
- The privacy screen's precision caption is true, the displayed request is
  built like the sent one, the geocoder request is shown, and coarser
  precision options warn before the tap.
- The PWA shell's title, description and boot screen say what the app is.

### Added
- `assets/fonts/OFL.txt`: the SIL Open Font License 1.1 text with the
  Lora and Nunito copyright notices (taken from the fonts' own
  metadata) now ships alongside the bundled faces, as the OFL requires;
  referenced from the README's Licence section. (Superseded by the fleet
  font migration above: the faces and their licence now ship with
  openhearth_design.)
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

### Fixed
- `startOfWeek` is now DST-safe: it uses calendar arithmetic
  (`DateTime(y, m, d - n)`) instead of Duration subtraction from local
  midnight, so a daylight-saving transition inside the week can no longer
  shift the week's Monday to 23:00/01:00 beside midnight. Synced with the
  fleet copies of `datetime_ext.dart`.

### Removed
- Unused direct `share_plus` dependency (the backup share flow lives in
  `sanctuary_backup_ui`, which declares its own).
