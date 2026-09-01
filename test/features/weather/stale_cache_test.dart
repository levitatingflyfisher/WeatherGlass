import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/freshness.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// audit humane-interface-05 (and ten more lenses, finding 1): when
/// Open-Meteo was unreachable, a readable forecast older than the 30-minute
/// TTL sat unused in Drift while Home printed an error. A failed fetch now
/// serves the cached forecast, marked stale with its age; the error state is
/// only for a place with nothing usable cached.
void main() {
  final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
      .readAsStringSync();
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
  const hour = 3600 * 1000;
  const now = 1000 * hour;

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  WeatherRepository repo(http.Client c) =>
      WeatherRepository(db, OpenMeteo(client: c));
  final offline =
      MockClient((_) async => throw http.ClientException('Failed to fetch'));
  Future<void> cacheRow(String payload, int at) => db
      .into(db.forecastCache)
      .insert(ForecastCacheCompanion.insert(
          locationId: 'L1', payload: payload, fetchedAt: at));

  group('repository', () {
    test('offline with a cached forecast past the TTL serves it, stale',
        () async {
      await cacheRow(fixture, now - 3 * hour);
      final f = await repo(offline).getForecast(loc,
          precision: LocationPrecision.balanced, nowMillis: now);
      expect(f.stale, isTrue);
      expect(f.fetchedAt, DateTime.fromMillisecondsSinceEpoch(now - 3 * hour));
    });

    test('a fresh fetch is not stale and carries its time', () async {
      final ok = MockClient((_) async => http.Response(fixture, 200));
      final f = await repo(ok).getForecast(loc,
          precision: LocationPrecision.balanced, nowMillis: now);
      expect(f.stale, isFalse);
      expect(f.fetchedAt, DateTime.fromMillisecondsSinceEpoch(now));
    });

    test('a fresh cached forecast carries its time and is not stale',
        () async {
      await cacheRow(fixture, now - 10 * 60 * 1000);
      final f = await repo(offline).getForecast(loc,
          precision: LocationPrecision.balanced, nowMillis: now);
      expect(f.stale, isFalse);
      expect(f.fetchedAt,
          DateTime.fromMillisecondsSinceEpoch(now - 10 * 60 * 1000));
    });

    test('a failed forced refresh falls back to the cache too', () async {
      await cacheRow(fixture, now - 10 * 60 * 1000);
      final f = await repo(offline).getForecast(loc,
          precision: LocationPrecision.balanced, force: true, nowMillis: now);
      expect(f.stale, isTrue);
    });

    test('offline with nothing cached still fails', () async {
      await expectLater(
          repo(offline).getForecast(loc,
              precision: LocationPrecision.balanced, nowMillis: now),
          throwsA(isA<http.ClientException>()));
    });

    test('offline with an unreadable cached row evicts it and fails',
        () async {
      await cacheRow('{}', now - 3 * hour);
      await expectLater(
          repo(offline).getForecast(loc,
              precision: LocationPrecision.balanced, nowMillis: now),
          throwsA(anything));
      expect(await db.select(db.forecastCache).get(), isEmpty);
    });

    test('a forecast older than its own 7-day window is not served',
        () async {
      await cacheRow(fixture, now - 8 * 24 * hour);
      await expectLater(
          repo(offline).getForecast(loc,
              precision: LocationPrecision.balanced, nowMillis: now),
          throwsA(anything));
    });
  });

  group('describeAge', () {
    for (final (d, words) in [
      (const Duration(seconds: 20), 'just now'),
      (const Duration(minutes: 1), '1 minute ago'),
      (const Duration(minutes: 12), '12 minutes ago'),
      (const Duration(hours: 1, minutes: 5), '1 hour ago'),
      (const Duration(hours: 3, minutes: 50), '3 hours ago'),
      (const Duration(days: 2, hours: 1), '2 days ago'),
    ]) {
      test('$d reads "$words"', () => expect(describeAge(d), words));
    }
  });

  group('on screen', () {
    Future<void> pump(WidgetTester tester, Forecast f) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 3000);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          forecastProvider(loc.id).overrideWith((ref) => f),
          clockProvider.overrideWithValue(
              () => DateTime.fromMillisecondsSinceEpoch(now)),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ForecastView(location: loc))),
      ));
      await tester.pumpAndSettle();
    }

    final base = Forecast.fromJson(
        jsonDecode(fixture) as Map<String, dynamic>);

    testWidgets('a stale forecast says how old it is and offers Try again',
        (tester) async {
      await pump(
          tester,
          base.withFreshness(
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(now - 3 * hour),
              stale: true));
      expect(find.textContaining('Couldn’t reach Open-Meteo'), findsOneWidget);
      expect(find.textContaining('3 hours ago'), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a fresh forecast carries a quiet "Updated" time only',
        (tester) async {
      await pump(
          tester,
          base.withFreshness(
              fetchedAt:
                  DateTime.fromMillisecondsSinceEpoch(now - 12 * 60 * 1000),
              stale: false));
      expect(find.textContaining('Updated 12 minutes ago'), findsOneWidget);
      expect(find.textContaining('Couldn’t reach'), findsNothing);
    });
  });

  group('a stale forecast never calls the past now', () {
    // Fetched at 11:00 on the 25th (so its current time is 11:00), shown at
    // 14:00 on the 26th. Place and clock both in UTC.
    Forecast staleFixture() {
      final base = DateTime(2026, 6, 25);
      return Forecast(
        current: CurrentConditions(
            time: DateTime(2026, 6, 25, 11),
            temperatureC: 20,
            apparentC: 20,
            weatherCode: 0,
            isDay: true,
            windKmh: 5,
            humidity: 50,
            precipMm: 0),
        hourly: [
          for (var i = 0; i < 72; i++)
            HourlyPoint(
                time: base.add(Duration(hours: i)),
                temperatureC: 18,
                precipProbability: 0,
                weatherCode: 0),
        ],
        daily: [
          for (var i = 0; i < 7; i++)
            DailyPoint(
                date: base.add(Duration(days: i)),
                weatherCode: 0,
                highC: 22,
                lowC: 12,
                precipProbabilityMax: 0),
        ],
        utcOffsetSeconds: 0,
        fetchedAt: DateTime.utc(2026, 6, 25, 11),
        stale: true,
      );
    }

    Future<void> pumpAt(WidgetTester tester, DateTime clock,
        {double scale = 1, Size size = const Size(400, 3000)}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          forecastProvider(loc.id).overrideWith((ref) => staleFixture()),
          clockProvider.overrideWithValue(() => clock),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const Scaffold(body: ForecastView(location: loc)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the hourly window and Today follow the real clock',
        (tester) async {
      await pumpAt(tester, DateTime.utc(2026, 6, 26, 14));
      final painter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is HourlyPainter))
          .painter! as HourlyPainter;
      expect(painter.hours.first.time, DateTime(2026, 6, 26, 14),
          reason: 'the first column (drawn as Now) is the real current hour');
      // The 25th is gone; the 26th is Today; six days remain.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Thu'), findsNothing, reason: 'June 25 2026 is past');
      expect(find.textContaining('1 day ago'), findsWidgets);
    });

    testWidgets('the stale notice fits at 320 dp x 3.0', (tester) async {
      await pumpAt(tester, DateTime.utc(2026, 6, 25, 14),
          scale: 3, size: const Size(320, 3000));
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
