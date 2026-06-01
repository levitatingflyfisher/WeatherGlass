@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';

import 'visual_golden_helper.dart';

// Plain (Roboto) theme — google_fonts would fetch fonts in a headless golden.
final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D82C9)),
);

SavedLocation _loc() => SavedLocation(
      id: 'berlin',
      label: 'Berlin',
      sublabel: 'Germany',
      lat: 52.52,
      lon: 13.41,
      isCurrent: false,
      sortOrder: 0,
      createdAt: 0,
    );

Forecast _forecast({required int code, required bool isDay}) {
  final base = DateTime(2026, 6, 25);
  return Forecast(
    current: CurrentConditions(
      time: DateTime(2026, 6, 25, 14, 0),
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
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final loc = _loc();
  await goldenAtSizes(
    tester,
    name: name,
    theme: _theme,
    sizes: const {'phone': Size(390, 844)},
    home: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        forecastProvider(loc.id)
            .overrideWith((ref) => _forecast(code: code, isDay: isDay)),
      ],
      child: Scaffold(body: ForecastView(location: loc)),
    ),
  );
}

void main() {
  testWidgets('forecast — clear day (the living-sky hero)', (tester) async {
    await _pumpForecast(tester, name: 'forecast_clear_day', code: 0, isDay: true);
  });

  testWidgets('forecast — rain', (tester) async {
    await _pumpForecast(tester, name: 'forecast_rain', code: 63, isDay: true);
  });

  testWidgets('forecast — clear night', (tester) async {
    await _pumpForecast(tester,
        name: 'forecast_clear_night', code: 0, isDay: false);
  });
}
