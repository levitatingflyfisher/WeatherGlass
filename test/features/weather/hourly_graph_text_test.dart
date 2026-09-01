import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loc = SavedLocation(
  id: 'b',
  label: 'Berlin',
  sublabel: null,
  lat: 52.52,
  lon: 13.41,
  isCurrent: false,
  sortOrder: 0,
  createdAt: 0,
);

Forecast _forecast() {
  final base = DateTime(2026, 6, 25);
  return Forecast(
    current: CurrentConditions(
        time: DateTime(2026, 6, 25, 14),
        temperatureC: 20,
        apparentC: 20,
        weatherCode: 0,
        isDay: true,
        windKmh: 5,
        humidity: 50,
        precipMm: 0),
    hourly: [
      for (var i = 0; i < 48; i++)
        HourlyPoint(
            time: base.add(Duration(hours: i)),
            temperatureC: 18.0 + i % 5,
            precipProbability: 40,
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
  );
}

Future<HourlyPainter> _painterAt(WidgetTester tester, double scale) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      forecastProvider(_loc.id).overrideWith((ref) => _forecast()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const Scaffold(body: ForecastView(location: _loc)),
    ),
  ));
  await tester.pumpAndSettle();
  final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is HourlyPainter));
  return paint.painter! as HourlyPainter;
}

/// audit visual-display-05, mind-in-mind-08: the hourly graph's numerals
/// were painted at literal 13/11/9.5 px with no textScaler and no font
/// family, so they ignored the reader's text size and fell back to the
/// platform sans beside Nunito and Lora.
void main() {
  testWidgets('the graph takes the reader\'s text scale', (tester) async {
    final at1 = await _painterAt(tester, 1.0);
    final at13 = await _painterAt(tester, 1.3);
    expect(at13.textScaler, const TextScaler.linear(1.3));
    expect(at13.bandScale, greaterThan(at1.bandScale),
        reason: 'the bands grow with the text, so labels do not collide');
  });

  testWidgets('the graph paints in the app\'s type, on the ladder',
      (tester) async {
    final p = await _painterAt(tester, 1.0);
    for (final s in [p.valueStyle, p.labelStyle]) {
      expect(s.fontFamily, 'packages/openhearth_design/Nunito');
      expect(s.fontSize, greaterThanOrEqualTo(13),
          reason: 'nothing below the ladder\'s smallest step');
    }
  });
}
