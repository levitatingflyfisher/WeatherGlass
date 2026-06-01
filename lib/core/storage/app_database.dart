// lib/core/storage/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

/// A place the household watches the weather for. Coordinates are stored ALREADY
/// rounded to the user's precision — WeatherGlass never persists a location finer than
/// it would send to a provider, so even a device dump leaks only a coarse cell.
@DataClassName('SavedLocation')
class SavedLocations extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()(); // "Berlin"
  TextColumn get sublabel => text().nullable()(); // "State of Berlin, Germany"
  RealColumn get lat => real()(); // rounded
  RealColumn get lon => real()(); // rounded
  // The single device-location entry, re-resolved (and re-rounded) on demand.
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached forecast JSON per location. Opening WeatherGlass is instant and offline-
/// friendly, and we touch the network as little as possible — fewer requests
/// means less for any observer to correlate.
@DataClassName('CachedForecast')
class ForecastCache extends Table {
  TextColumn get locationId => text()();
  TextColumn get payload => text()(); // raw Open-Meteo JSON
  IntColumn get fetchedAt => integer()(); // epoch ms

  @override
  Set<Column> get primaryKey => {locationId};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [SavedLocations, ForecastCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'glass',
              // Web needs to know where the sqlite3 WASM engine + drift worker
              // live (both shipped in web/); without this drift_flutter throws
              // "the `web` parameter needs to be set" at startup.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );
}
