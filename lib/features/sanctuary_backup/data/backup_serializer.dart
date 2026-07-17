import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/app_database.dart';
import '../../settings/domain/settings.dart';

/// Serializes WeatherGlass's user data to/from a JSON [Uint8List] for
/// encrypted backup via sanctuary_backup_ui.
///
/// **Scope: SavedLocations + settings. ForecastCache is deliberately
/// excluded.** The forecast cache is disposable derived data — raw
/// Open-Meteo JSON, re-fetched automatically the next time a saved place is
/// viewed (`WeatherRepository`'s cache-aware `getForecast`). Backing it up
/// would bloat every `.ohbk` file with public weather data the user never
/// chose, and a restored cache could already be stale the moment it lands.
/// Saved places and settings (units, location precision, theme) are the
/// durable choices worth encrypting and restoring — `precision` in
/// particular is privacy-relevant, so silently losing it on restore would
/// widen the coordinate-rounding cell back to the default without the user
/// asking for that.
///
/// Settings live in [SharedPreferences], not Drift, so they can't join the
/// Drift transaction that restores `SavedLocations`. To keep the
/// fail-closed guarantee (a rejected restore touches nothing) the *entire*
/// payload — app id, schema version, tables, AND settings — is validated
/// before any write; only once everything has been checked does the Drift
/// transaction run, followed by the (non-transactional, but by-then
/// guaranteed-valid) preference writes.
class GlassBackupSerializer
    implements BackupSerializer, PreviewableBackupSerializer {
  static const _appId = 'weatherglass';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  const GlassBackupSerializer(this._db, this._prefs);

  /// Reads saved places and the settings snapshot and returns the JSON
  /// payload as bytes.
  @override
  Future<Uint8List> dumpAll() async {
    final allLocations = await _db.select(_db.savedLocations).get();

    // The shape is WeatherGlass's SHIPPED one (`app`/`schemaVersion`/
    // `exportedAt`/top-level `tables`+`settings`) with one ADDITIVE key the
    // v0.2.0 retention spec needs (`createdAt`, feeding preview/staleness
    // copy). Shipped readers ignore unknown keys, so backups made by this
    // build still restore on pre-v0.2.0 installs — the wire format is
    // extended, never broken.
    final stamp = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'app': _appId,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': stamp,
      'createdAt': stamp,
      'tables': {
        'savedLocations': allLocations.map((r) => r.toJson()).toList(),
      },
      'settings': {
        'units': _prefs.getString(SettingsPrefsKeys.units),
        'precision': _prefs.getString(SettingsPrefsKeys.precision),
        'themeMode': _prefs.getString(SettingsPrefsKeys.themeMode),
      },
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  /// The dry-run parse behind preview-before-restore and export
  /// verify-by-read-back: validates exactly like [restoreAll] (envelope via
  /// [BackupEnvelope.unwrap], content via [_requireContent]) and reports
  /// row counts — but never writes.
  @override
  Future<BackupManifest> describeBackup(Uint8List plaintext) async {
    _requireContent(_unwrap(plaintext).payload);
    return BackupEnvelope.describe(plaintext);
  }

  /// The content gate [restoreAll] applies past the envelope — shared so
  /// describe and restore can never drift apart (the Sundial/Lullaby
  /// shared-gate pattern). `settings` is load-bearing here: losing the
  /// `precision` snapshot would silently widen the coordinate-rounding
  /// cell, so a payload without it is rejected, not tolerated.
  static ({Map<String, dynamic> tables, Map<String, dynamic> settings})
      _requireContent(Map<String, Object?> payload) {
    final tables = payload['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Missing tables in backup payload');
    }
    final settings = payload['settings'];
    if (settings is! Map<String, dynamic>) {
      throw const FormatException('Missing settings in backup payload');
    }
    return (tables: tables, settings: settings);
  }

  /// Envelope validation via the shared fleet helper. WeatherGlass has
  /// always emitted the `app` key, so the strict default (requireAppKey:
  /// true) applies; unwrap stays tolerant of the shipped shape (top-level
  /// `tables`, `exportedAt` as the stamp, no `payload` key).
  UnwrappedBackup _unwrap(Uint8List data) => BackupEnvelope.unwrap(
        data,
        expectedAppId: _appId,
        currentSchemaVersion: _db.schemaVersion,
      );

  /// Restores saved places and settings from a JSON [Uint8List] previously
  /// created by [dumpAll].
  ///
  /// **This is destructive** — existing saved places (and the forecast
  /// cache, which isn't part of the backup) are wiped before inserting.
  ///
  /// Throws [FormatException] if the payload is not valid JSON, is from a
  /// different app, or is missing required fields.
  /// Throws [BackupSchemaException] if the payload's schema version is newer
  /// than the current database version.
  @override
  Future<void> restoreAll(Uint8List data) async {
    // Everything is validated before any write — a rejected restore must
    // never touch existing data or settings (SANCTUARY-BRIEF §2.4/§2.8).
    final content = _requireContent(_unwrap(data).payload);
    final locations = _jsonList(content.tables, 'savedLocations');
    final settings = content.settings;

    // SavedLocations is a leaf table (no FKs) and ForecastCache is excluded
    // from the backup entirely, so there's no insert ordering to worry
    // about — wipe and reinsert inside one transaction.
    await _db.transaction(() async {
      await _db.delete(_db.savedLocations).go();
      // Cache rows for wiped/replaced places are harmless to leave (the
      // cache-aware fetch re-keys by locationId and just misses), but
      // clearing them keeps a restored place from ever coincidentally
      // reading another install's stale cache under a re-used id.
      await _db.delete(_db.forecastCache).go();

      for (final row in locations) {
        await _db.into(_db.savedLocations).insert(
              SavedLocationsCompanion.insert(
                id: row['id'] as String,
                label: row['label'] as String,
                sublabel: Value(row['sublabel'] as String?),
                lat: (row['lat'] as num).toDouble(),
                lon: (row['lon'] as num).toDouble(),
                isCurrent: Value(row['isCurrent'] as bool? ?? false),
                sortOrder: Value(row['sortOrder'] as int? ?? 0),
                createdAt: row['createdAt'] as int,
              ),
            );
      }
    });

    // Preference writes happen only after the Drift transaction has
    // committed successfully, and only with values already validated above
    // — SharedPreferences has no transaction to join, but by this point the
    // whole payload is known-good, so there is nothing left to fail on.
    final units = settings['units'] as String?;
    final precision = settings['precision'] as String?;
    final themeMode = settings['themeMode'] as String?;
    if (units != null) {
      await _prefs.setString(SettingsPrefsKeys.units, units);
    }
    if (precision != null) {
      await _prefs.setString(SettingsPrefsKeys.precision, precision);
    }
    if (themeMode != null) {
      await _prefs.setString(SettingsPrefsKeys.themeMode, themeMode);
    }
  }

  List<Map<String, dynamic>> _jsonList(
    Map<String, dynamic> tables,
    String key,
  ) {
    final list = tables[key] as List<dynamic>?;
    if (list == null) return const [];
    return list.cast<Map<String, dynamic>>();
  }
}
