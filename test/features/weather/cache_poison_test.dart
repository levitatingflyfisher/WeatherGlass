import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A 200 response with valid JSON but the wrong shape (Forecast.fromJson throws)
/// must never poison the on-disk cache, and a row poisoned by an older build
/// must self-heal on the next read instead of throwing forever.
void main() {
  final fixture =
      File('test/features/weather/fixtures/forecast_berlin.json').readAsStringSync();

  SavedLocation loc() => SavedLocation(
        id: 'L1',
        label: 'Berlin',
        sublabel: null,
        lat: 52.5,
        lon: 13.4,
        isCurrent: false,
        sortOrder: 0,
        createdAt: 0,
      );

  test('an unparseable 200 body is not written to the cache', () async {
    final mock = MockClient((_) async => http.Response('{}', 200));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WeatherRepository(db, OpenMeteo(client: mock));

    await expectLater(
      repo.getForecast(loc(), precision: LocationPrecision.precise),
      throwsA(anything),
    );
    final rows = await db.select(db.forecastCache).get();
    expect(rows, isEmpty,
        reason: 'a valid-JSON-but-unparseable body must never poison the cache');
  });

  test('a pre-poisoned cache row self-heals on the next non-forced read',
      () async {
    final mock = MockClient((_) async => http.Response(fixture, 200));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WeatherRepository(db, OpenMeteo(client: mock));

    // A fresh (under-ttl) but junk cache row, as an older build could have left.
    await db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
          locationId: 'L1',
          payload: '{}',
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ));

    final f = await repo.getForecast(loc(), precision: LocationPrecision.precise);
    expect(f, isA<Forecast>(),
        reason: 'a poisoned cache row must be evicted and refetched, not rethrown');
  });
}
