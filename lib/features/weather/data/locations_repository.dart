// lib/features/weather/data/locations_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:glass/core/storage/app_database.dart';

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

  Future<void> remove(String id) async {
    await (_db.delete(_db.forecastCache)..where((t) => t.locationId.equals(id)))
        .go();
    await (_db.delete(_db.savedLocations)..where((t) => t.id.equals(id))).go();
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
