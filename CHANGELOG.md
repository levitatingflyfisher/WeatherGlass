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

### Changed
- Backup/restore now rides `sanctuary_backup_ui` 0.2.0.
