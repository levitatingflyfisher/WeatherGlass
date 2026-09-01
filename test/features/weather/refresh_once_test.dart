import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A failed refresh used to make two attempts: the forced fetch, then the
/// provider recomputing after invalidate, which fetched again because the
/// cache was past its TTL. One tap, one attempt.
void main() {
  const loc = SavedLocation(
    id: 'L1',
    label: 'Berlin',
    sublabel: null,
    lat: 52.52,
    lon: 13.41,
    isCurrent: false,
    sortOrder: 0,
    createdAt: 0,
  );

  testWidgets('Try again on a stale forecast makes exactly one fetch attempt',
      (tester) async {
    final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    var requests = 0;
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(() => db.into(db.forecastCache).insert(
        ForecastCacheCompanion.insert(
            locationId: loc.id,
            payload: fixture,
            fetchedAt: now - 3 * 3600 * 1000)));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        savedLocationsProvider.overrideWith((ref) => Stream.value([loc])),
        openMeteoProvider.overrideWithValue(_Offline(() => requests++)),
      ],
      child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ForecastView(location: loc))),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.textContaining('Couldn’t reach Open-Meteo'), findsOneWidget);
    final before = requests;

    await tester.tap(find.text('Try again'));
    await settle();
    expect(requests - before, 1, reason: 'one tap, one fetch attempt');
    expect(find.textContaining('Couldn’t reach Open-Meteo'), findsOneWidget,
        reason: 'the stale notice stays');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}

/// Counts forecast fetch attempts (the client's own transport retries sit
/// below this and are not what 'two attempts' meant).
class _Offline extends OpenMeteo {
  _Offline(this.onAttempt);
  final void Function() onAttempt;
  @override
  Future<String> fetchForecastJson(double lat, double lon) async {
    onAttempt();
    throw http.ClientException('offline');
  }
}
