// lib/features/weather/data/locations_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/domain/geo.dart';

/// CRUD for saved places. Coordinates passed in are expected to be ALREADY
/// rounded to the user's precision (the add/locate flows round at the boundary)
/// — this layer never sees or stores a finer coordinate.
class LocationsRepository {
  LocationsRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<SavedLocation>> watchAll() => (_db.select(_db.savedLocations)
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .watch();

  Future<List<SavedLocation>> all() => (_db.select(_db.savedLocations)
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .get();

  Future<SavedLocation?> byId(String id) =>
      (_db.select(_db.savedLocations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> _nextOrder() async {
    final rows = await all();
    return rows.isEmpty
        ? 0
        : rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<String> add({
    required String label,
    String? sublabel,
    required double lat,
    required double lon,
    bool isCurrent = false,
    int? nowMillis,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.savedLocations).insert(SavedLocationsCompanion.insert(
          id: id,
          label: label,
          sublabel: Value(sublabel),
          lat: lat,
          lon: lon,
          isCurrent: Value(isCurrent),
          sortOrder: Value(await _nextOrder()),
          createdAt: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
        ));
    return id;
  }

  /// Insert or update the single "current location" entry (re-resolved from the
  /// device each time the user taps locate-me). Returns its id.
  Future<String> upsertCurrent({
    required String label,
    String? sublabel,
    required double lat,
    required double lon,
    int? nowMillis,
  }) async {
    final existing = await (_db.select(_db.savedLocations)
          ..where((t) => t.isCurrent.equals(true)))
        .getSingleOrNull();
    if (existing == null) {
      return add(
          label: label,
          sublabel: sublabel,
          lat: lat,
          lon: lon,
          isCurrent: true,
          nowMillis: nowMillis);
    }
    await (_db.update(_db.savedLocations)
          ..where((t) => t.id.equals(existing.id)))
        .write(SavedLocationsCompanion(
      label: Value(label),
      sublabel: Value(sublabel),
      lat: Value(lat),
      lon: Value(lon),
    ));
    // A re-resolved current location invalidates its cached forecast.
    await (_db.delete(_db.forecastCache)
          ..where((t) => t.locationId.equals(existing.id)))
        .go();
    return existing.id;
  }

  /// Remove a place and its cached forecast, returning both so the Places
  /// screen's Undo can put them back exactly ([restore]).
  Future<RemovedPlace> remove(String id) async {
    final cache = await (_db.select(_db.forecastCache)
          ..where((t) => t.locationId.equals(id)))
        .getSingleOrNull();
    final row = await byId(id);
    await (_db.delete(_db.forecastCache)..where((t) => t.locationId.equals(id)))
        .go();
    await (_db.delete(_db.savedLocations)..where((t) => t.id.equals(id))).go();
    return RemovedPlace(row, cache);
  }

  /// Undo a [remove]: the row returns with its id and list position, and its
  /// cached forecast returns too, so Undo costs no network request.
  ///
  /// The coordinate is re-rounded to [precision] first, so Undo can never
  /// bring back a finer coordinate than the setting now allows (and then the
  /// cached payload, which embeds the old coordinate, is dropped). If a new
  /// "My location" was resolved in the meantime, the restored one comes back
  /// as an ordinary place, so there is still exactly one current location.
  Future<void> restore(RemovedPlace removed,
      {required LocationPrecision precision}) async {
    final row = removed.location;
    if (row == null) return;
    final (lat, lon) = roundForPrecision(row.lat, row.lon, precision);
    final hasCurrent = row.isCurrent &&
        await (_db.select(_db.savedLocations)
                  ..where((t) => t.isCurrent.equals(true)))
                .getSingleOrNull() !=
            null;
    await _db.transaction(() async {
      await _db.into(_db.savedLocations).insertOnConflictUpdate(row.copyWith(
          lat: lat, lon: lon, isCurrent: row.isCurrent && !hasCurrent));
      final cache = removed.cache;
      if (cache != null && lat == row.lat && lon == row.lon) {
        await _db.into(_db.forecastCache).insertOnConflictUpdate(cache);
      }
    });
  }

  /// Coarsen every saved row to [precision]'s grid, evicting the forecast
  /// cache of each row that changed (its payload embeds the finer coordinate).
  /// Called when the user lowers the precision setting: the promise is "a
  /// device dump leaks only a coarse cell", so the finer coordinate must leave
  /// the DB — not just the outbound URL. Rounding an already-coarse row is a
  /// no-op, so raising precision changes nothing (rounding cannot be undone).
  Future<void> reRoundAll(LocationPrecision precision) async {
    for (final r in await all()) {
      final (lat, lon) = roundForPrecision(r.lat, r.lon, precision);
      if (lat == r.lat && lon == r.lon) continue;
      await (_db.update(_db.savedLocations)..where((t) => t.id.equals(r.id)))
          .write(SavedLocationsCompanion(lat: Value(lat), lon: Value(lon)));
      await (_db.delete(_db.forecastCache)
            ..where((t) => t.locationId.equals(r.id)))
          .go();
    }
  }

  Future<void> reorder(List<String> idsInOrder) async {
    await _db.batch((b) {
      for (var i = 0; i < idsInOrder.length; i++) {
        b.update(
          _db.savedLocations,
          SavedLocationsCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(idsInOrder[i]),
        );
      }
    });
  }
}

/// What [LocationsRepository.remove] took: the place row (null if it was
/// already gone) and its cached forecast, if any.
class RemovedPlace {
  const RemovedPlace(this.location, this.cache);
  final SavedLocation? location;
  final CachedForecast? cache;
}
