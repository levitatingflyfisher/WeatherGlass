import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/data/locations_repository.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lowering the precision setting is a PRIVACY action: the user is asking for
/// a coarser grid on disk, not just on the wire. The send boundary already
/// re-rounds outbound requests, but rows saved earlier at a finer precision
/// kept their fine coordinate — and their cached forecast payloads embed it —
/// so a device dump still leaked the block-scale home cell. setPrecision must
/// re-round the stored rows and drop the stale cache entries.
void main() {
  Future<(ProviderContainer, AppDatabase)> makeContainer() async {
    final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    final mock = MockClient((_) async => http.Response(fixture, 200));
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
    return (container, db);
  }

  test('lowering precision re-rounds saved rows and evicts their cache',
      () async {
    final (container, db) = await makeContainer();

    // A place saved while the setting was "precise" (3 dp, ~110 m).
    final id = await LocationsRepository(db)
        .add(label: 'Home', lat: 12.345, lon: 98.765);
    await db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
          locationId: id,
          payload: '{"latitude":12.345,"longitude":98.765}',
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ));

    // The user lowers to the most-private setting.
    await container
        .read(settingsProvider.notifier)
        .setPrecision(LocationPrecision.coarse);

    final row = await db.select(db.savedLocations).getSingle();
    expect(row.lat, roundCoord(12.345, LocationPrecision.coarse.decimals),
        reason: 'the stored latitude must be coarsened to the new grid');
    expect(row.lon, roundCoord(98.765, LocationPrecision.coarse.decimals),
        reason: 'the stored longitude must be coarsened to the new grid');
    expect(await db.select(db.forecastCache).get(), isEmpty,
        reason: 'the cached payload embeds the finer coordinate — evict it');
  });

  test('rows already on the new grid are untouched and keep their cache',
      () async {
    final (container, db) = await makeContainer();

    // Saved at coarse (1 dp) — already as coarse as the new setting.
    final id = await LocationsRepository(db)
        .add(label: 'Town', lat: 12.3, lon: 98.7, nowMillis: 1000);
    final fetchedAt = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
          locationId: id,
          payload: '{"latitude":12.3,"longitude":98.7}',
          fetchedAt: fetchedAt,
        ));

    await container
        .read(settingsProvider.notifier)
        .setPrecision(LocationPrecision.balanced);

    final row = await db.select(db.savedLocations).getSingle();
    expect((row.lat, row.lon), (12.3, 98.7));
    expect((await db.select(db.forecastCache).get()).length, 1,
        reason: 'an unchanged row leaks nothing — no need to refetch');
  });
}
