import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/locations_repository.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relocating "My location" (re-resolving current into a new rounded cell)
/// updates the saved row's coords and clears its cached forecast. The Home page
/// stays mounted behind the add-sheet, so its forecast provider is NOT torn
/// down — it must recompute for the new coordinates rather than keep showing the
/// old location's weather. Regression for the one-shot `byId` read that wasn't
/// reactive to a coordinate UPDATE.
void main() {
  test('forecast refetches at the new coordinates after a relocate', () async {
    final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    final requestedLats = <String>[];
    final mock = MockClient((req) async {
      final lat = req.url.queryParameters['latitude'];
      if (lat != null) requestedLats.add(lat);
      return http.Response(fixture, 200);
    });

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      openMeteoProvider.overrideWithValue(OpenMeteo(client: mock)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final repo = container.read(locationsRepositoryProvider);
    final id =
        await repo.upsertCurrent(label: 'My location', lat: 12.5, lon: 55.5);

    // Home watches the forecast; keep it alive so a relocate can recompute it.
    container.listen(forecastProvider(id), (_, __) {}, fireImmediately: true);
    await container.read(forecastProvider(id).future);
    final firstLat = requestedLats.isNotEmpty ? requestedLats.first : null;
    expect(firstLat, isNotNull);

    // Relocate the same current row to a far-away cell (also clears its cache).
    await repo.upsertCurrent(label: 'My location', lat: 48.25, lon: 2.5);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await container.read(forecastProvider(id).future);

    expect(requestedLats.length, greaterThanOrEqualTo(2),
        reason: 'a relocate must trigger a fresh forecast fetch');
    expect(requestedLats.last, isNot(firstLat),
        reason: 'the refetch must use the new coordinates, not the stale ones');
  });

  test('getForecast re-rounds to the CURRENT precision at the send boundary',
      () async {
    final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    final sentLats = <String>[];
    final mock = MockClient((req) async {
      final lat = req.url.queryParameters['latitude'];
      if (lat != null) sentLats.add(lat);
      return http.Response(fixture, 200);
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WeatherRepository(db, OpenMeteo(client: mock));

    // A place saved earlier at block-scale (fine) precision.
    await LocationsRepository(db)
        .upsertCurrent(label: 'Home', lat: 12.345, lon: 98.765);
    final loc = await db.select(db.savedLocations).getSingle();

    // The user has since switched to the most-private (coarse) precision.
    await repo.getForecast(loc, precision: LocationPrecision.coarse);

    final (rlat, _) = roundForPrecision(12.345, 98.765, LocationPrecision.coarse);
    expect(sentLats.single, rlat.toString(),
        reason: 'the outbound request must carry the coarsened coordinate');
    expect(sentLats.single, isNot('12.345'),
        reason: 'the finer saved coordinate must NOT leak after lowering precision');
  });
}
