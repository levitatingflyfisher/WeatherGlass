import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/locations_repository.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/presentation/locations_screen.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removing a place is a deliberate tap, so per the fleet delete ruling it
/// does not ask first: it removes at once and offers an Undo that never
/// expires. Undo must bring back exactly what went — the row, its place in
/// the list, and its cached forecast (so Undo costs no network request).
void main() {
  late AppDatabase db;
  late LocationsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocationsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> cache(String id) =>
      db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
          locationId: id, payload: '{"cached":true}', fetchedAt: 42));

  test('remove returns what it took and restore puts all of it back', () async {
    final a = await repo.add(label: 'Berlin', lat: 52.52, lon: 13.41);
    final b = await repo.add(label: 'Oslo', lat: 59.91, lon: 10.75);
    await cache(a);

    final removed = await repo.remove(a);
    expect((await repo.all()).map((l) => l.id), [b]);
    expect(await db.select(db.forecastCache).get(), isEmpty);

    await repo.restore(removed, precision: LocationPrecision.balanced);
    final all = await repo.all();
    expect(all.map((l) => l.id), [a, b], reason: 'back in its old place');
    final cached = await db.select(db.forecastCache).getSingle();
    expect(cached.locationId, a);
    expect(cached.fetchedAt, 42);
  });

  test('restore never brings back a coordinate finer than the setting',
      () async {
    final a = await repo.add(label: 'Berlin', lat: 52.523, lon: 13.413);
    await cache(a);
    final removed = await repo.remove(a);

    await repo.restore(removed, precision: LocationPrecision.coarse);
    final row = (await repo.all()).single;
    expect((row.lat, row.lon), (52.5, 13.4));
    expect(await db.select(db.forecastCache).get(), isEmpty,
        reason: 'the cached payload embeds the finer coordinate');
  });

  test('restoring "My location" after a new one was resolved keeps one',
      () async {
    final a = await repo.upsertCurrent(label: 'My location', lat: 1, lon: 1);
    final removed = await repo.remove(a);
    await repo.upsertCurrent(label: 'My location', lat: 2, lon: 2);

    await repo.restore(removed, precision: LocationPrecision.balanced);
    final current = (await repo.all()).where((l) => l.isCurrent);
    expect(current, hasLength(1));
  });

  testWidgets('the trash button removes at once and Undo brings it back',
      (tester) async {
    final fake = _FakeRepo(db)
      ..rows = [
        const SavedLocation(
            id: 'b',
            label: 'Berlin',
            sublabel: null,
            lat: 52.52,
            lon: 13.41,
            isCurrent: false,
            sortOrder: 0,
            createdAt: 0),
      ];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationsRepositoryProvider.overrideWithValue(fake),
        weatherRepositoryProvider.overrideWithValue(_NoWeather(db)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const LocationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Berlin'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Berlin'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing, reason: 'no dialog');
    expect(find.text('Berlin'), findsNothing);
    expect(find.text('Removed Berlin'), findsOneWidget);

    // Undo never times out.
    await tester.pump(const Duration(hours: 1));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Berlin'), findsOneWidget);
    expect(find.text('Removed Berlin'), findsNothing);
  });
}

/// An in-memory repository: a widget test cannot pump a live Drift stream.
class _FakeRepo extends LocationsRepository {
  _FakeRepo(super.db);
  List<SavedLocation> rows = [];
  final _ctrl = StreamController<List<SavedLocation>>.broadcast();

  @override
  Stream<List<SavedLocation>> watchAll() async* {
    yield rows;
    yield* _ctrl.stream;
  }

  @override
  Future<RemovedPlace> remove(String id) async {
    final row = rows.firstWhere((r) => r.id == id);
    rows = [...rows]..remove(row);
    _ctrl.add(rows);
    return RemovedPlace(row, null);
  }

  @override
  Future<void> restore(RemovedPlace removed,
      {required LocationPrecision precision}) async {
    rows = [...rows, removed.location!];
    _ctrl.add(rows);
  }
}

class _NoWeather extends WeatherRepository {
  _NoWeather(AppDatabase db) : super(db, OpenMeteo());
  @override
  Future<Forecast> getForecast(SavedLocation loc,
          {required LocationPrecision precision,
          bool force = false,
          int? nowMillis}) =>
      Future.error(Exception('offline'));
}
