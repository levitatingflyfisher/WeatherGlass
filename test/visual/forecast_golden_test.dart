@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';

import 'visual_golden_helper.dart';

// The app's real theme, so a change to the shared type ladder or tokens
// shows up here (the fonts are bundled package fonts, loaded by
// flutter_test_config.dart — nothing is fetched).
final _theme = AppTheme.light;

SavedLocation _loc() => const SavedLocation(
      id: 'berlin',
      label: 'Berlin',
      sublabel: 'Germany',
      lat: 52.52,
      lon: 13.41,
      isCurrent: false,
      sortOrder: 0,
      createdAt: 0,
    );

Forecast _forecast({required int code, required bool isDay, int hour = 14}) {
  final base = DateTime(2026, 6, 25);
  return Forecast(
    current: CurrentConditions(
      time: DateTime(2026, 6, 25, hour, 0),
      temperatureC: 23.6,
      apparentC: 24.8,
      weatherCode: code,
      isDay: isDay,
      windKmh: 12,
      humidity: 47,
      precipMm: code >= 51 ? 1.2 : 0,
    ),
    hourly: [
      for (var i = 0; i < 48; i++)
        HourlyPoint(
          time: base.add(Duration(hours: i)),
          temperatureC: 18 + (i % 8),
          precipProbability: code >= 51 ? 40 + (i % 5) * 8 : (i % 4) * 5,
          weatherCode: code,
        ),
    ],
    daily: [
      for (var i = 0; i < 7; i++)
        DailyPoint(
          date: base.add(Duration(days: i)),
          weatherCode: i.isEven ? code : 1,
          highC: 25 - i.toDouble(),
          lowC: 14 - (i % 3).toDouble(),
          precipProbabilityMax: code >= 51 ? 60 - i * 5 : i * 6,
        ),
    ],
    utcOffsetSeconds: 7200,
  );
}

Future<void> _pumpForecast(
  WidgetTester tester, {
  required String name,
  required int code,
  required bool isDay,
  Map<String, Size> sizes = const {'phone': Size(390, 844)},
  List<double> textScales = const [1.0],
  bool stale = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final loc = _loc();
  await goldenAtSizes(
    tester,
    name: name,
    theme: _theme,
    sizes: sizes,
    textScales: textScales,
    home: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        forecastProvider(loc.id).overrideWith((ref) {
          // A real stale payload: its current time is when it was fetched
          // (11:00), three hours before the clock (14:00).
          return stale
              ? _forecast(code: code, isDay: isDay, hour: 11).withFreshness(
                  fetchedAt: DateTime.utc(2026, 6, 25, 9), stale: true)
              : _forecast(code: code, isDay: isDay);
        }),
        // 14:00 at the place (UTC+2), independent of the test machine's zone.
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 6, 25, 12)),
      ],
      child: Scaffold(body: ForecastView(location: loc)),
    ),
  );
}

void main() {
  testWidgets('forecast — clear day (the living-sky hero)', (tester) async {
    await _pumpForecast(tester,
        name: 'forecast_clear_day', code: 0, isDay: true);
  });

  testWidgets('forecast — rain', (tester) async {
    await _pumpForecast(tester, name: 'forecast_rain', code: 63, isDay: true);
  });

  testWidgets('forecast — clear night', (tester) async {
    await _pumpForecast(tester,
        name: 'forecast_clear_night', code: 0, isDay: false);
  });

  // The narrow phone at default and enlarged text: the 7-day row and the
  // hourly graph are where a fixed width sized for scale 1.0 breaks.
  testWidgets('forecast — 360 dp at text scale 1.0, 1.3 and 2.0', (tester) async {
    await _pumpForecast(tester,
        name: 'forecast_narrow',
        code: 0,
        isDay: true,
        sizes: const {'phone': Size(360, 1400)},
        textScales: const [1.0, 1.3, 2.0]);
  });

  // Open-Meteo unreachable, a 3-hour-old forecast cached: the weather stays,
  // with its age and Try again, instead of an error page.
  testWidgets('forecast — served stale from the cache', (tester) async {
    await _pumpForecast(tester,
        name: 'forecast_stale', code: 3, isDay: true, stale: true);
  });
}
