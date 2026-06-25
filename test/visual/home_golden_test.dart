@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';

import 'visual_golden_helper.dart';

final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D82C9)),
);

SavedLocation _loc(String id, String label) => SavedLocation(
      id: id,
      label: label,
      sublabel: null,
      lat: 52.52,
      lon: 13.41,
      isCurrent: false,
      sortOrder: 0,
      createdAt: 0,
    );

Forecast _forecast(int code) {
  final base = DateTime(2026, 6, 25);
  return Forecast(
    current: CurrentConditions(
      time: DateTime(2026, 6, 25, 14),
      temperatureC: 23.6,
      apparentC: 24.8,
      weatherCode: code,
      isDay: true,
      windKmh: 12,
      humidity: 47,
      precipMm: 0,
    ),
    hourly: [
      for (var i = 0; i < 48; i++)
        HourlyPoint(
          time: base.add(Duration(hours: i)),
          temperatureC: 18 + (i % 9),
          precipProbability: (i % 5) * 12,
          weatherCode: code,
        ),
    ],
    daily: [
      for (var i = 0; i < 7; i++)
        DailyPoint(
          date: base.add(Duration(days: i)),
          weatherCode: code,
          highC: 25 - i.toDouble(),
          lowC: 14 - (i % 3).toDouble(),
          precipProbabilityMax: i * 8,
        ),
    ],
    utcOffsetSeconds: 7200,
  );
}

void main() {
  testWidgets('home — multiple places show named, tappable city tabs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final berlin = _loc('berlin', 'Berlin');
    final london = _loc('london', 'London');
    final tokyo = _loc('tokyo', 'Tokyo');

    await goldenAtSizes(
      tester,
      name: 'home_multi',
      theme: _theme,
      sizes: const {'phone': Size(390, 844)},
      home: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLocationsProvider
              .overrideWith((ref) => Stream.value([berlin, london, tokyo])),
          forecastProvider(berlin.id).overrideWith((ref) => _forecast(0)),
          forecastProvider(london.id).overrideWith((ref) => _forecast(3)),
          forecastProvider(tokyo.id).overrideWith((ref) => _forecast(61)),
        ],
        child: const HomeScreen(),
      ),
    );
  });
}
