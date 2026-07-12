import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart'
    show BackupFormatException;
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
class GlassBackupSerializer implements BackupSerializer {
  static const _appId = 'weatherglass';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  const GlassBackupSerializer(this._db, this._prefs);

  /// Reads saved places and the settings snapshot and returns the JSON
  /// payload as bytes.
  @override
  Future<Uint8List> dumpAll() async {
    final allLocations = await _db.select(_db.savedLocations).get();

    final payload = <String, dynamic>{
      'app': _appId,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
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

  /// Restores saved places and settings from a JSON [Uint8List] previously
  /// created by [dumpAll].
  ///
  /// **This is destructive** — existing saved places (and the forecast
  /// cache, which isn't part of the backup) are wiped before inserting.
  ///
  /// Throws [BackupFormatException] if the payload is from a different app.
  /// Throws [BackupSchemaException] if the payload's schema version is newer
  /// than the current database version.
  /// Throws [FormatException] if the payload is not valid JSON or is missing
  /// required fields.
  @override
  Future<void> restoreAll(Uint8List data) async {
    final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;

    // Everything is validated before any write — a rejected restore must
    // never touch existing data or settings (SANCTUARY-BRIEF §2.4/§2.8).
    final app = json['app'] as String?;
    if (app != _appId) {
      throw BackupFormatException(
        'This backup is from a different app ("${app ?? 'unknown'}"), not WeatherGlass.',
      );
    }

    final version = json['schemaVersion'] as int?;
    if (version == null) {
      throw const FormatException('Missing schemaVersion in backup payload');
    }
    if (version > _db.schemaVersion) {
      throw BackupSchemaException(version, _db.schemaVersion);
    }

    final tables = json['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const FormatException('Missing tables in backup payload');
    }
    final locations = _jsonList(tables, 'savedLocations');

    final settings = json['settings'] as Map<String, dynamic>?;
    if (settings == null) {
      throw const FormatException('Missing settings in backup payload');
    }

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
