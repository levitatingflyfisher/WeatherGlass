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
  id: 'berlin',
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
      temperatureC: 23.6,
      apparentC: 24.8,
      weatherCode: 0,
      isDay: true,
      windKmh: 12,
      humidity: 47,
      precipMm: 0,
    ),
    hourly: [
      for (var i = 0; i < 48; i++)
        HourlyPoint(
          time: base.add(Duration(hours: i)),
          temperatureC: 18.0 + (i % 8),
          precipProbability: 0,
          weatherCode: 0,
        ),
    ],
    daily: [
      for (var i = 0; i < 7; i++)
        DailyPoint(
          date: base.add(Duration(days: i)),
          weatherCode: 61,
          highC: 25 - i.toDouble(),
          lowC: -14 + i.toDouble(),
          precipProbabilityMax: 98,
        ),
    ],
    utcOffsetSeconds: 7200,
  );
}

Future<void> _pump(WidgetTester tester, double scale) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      forecastProvider(_loc.id).overrideWith((ref) => _forecast()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(body: ForecastView(location: _loc)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // audit mind-in-mind-04/14, visual-display-16: fixed SizedBox widths sized
  // for scale 1.0 broke "Today" into "Tod / ay" and "98%" into "98 / %".
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('7-day row words stay on one line at 360 dp x $scale',
        (tester) async {
      await _pump(tester, scale);
      final oneLine = tester.getSize(find.text('Fri')).height;
      for (final label in ['Today', '98%', '-14°', '25°']) {
        final f = find.text(label);
        expect(f, findsWidgets, reason: label);
        // Styles differ by a pixel of leading; a wrap doubles the height.
        expect(tester.getSize(f.first).height, lessThan(oneLine * 1.5),
            reason: '"$label" wrapped at text scale $scale');
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Follow-up: at 360 dp x 2.0 the text columns took all the width and the
  // range bar shrank to 0 px. It must stay a readable bar at every scale.
  for (final scale in [1.0, 1.3, 2.0, 3.0]) {
    testWidgets('every range bar is at least 48 dp wide at 360 dp x $scale',
        (tester) async {
      await _pump(tester, scale);
      for (var i = 0; i < 7; i++) {
        final bar = find.byKey(ValueKey('range-bar-$i'));
        expect(bar, findsOneWidget);
        expect(tester.getSize(bar).width, greaterThanOrEqualTo(48),
            reason: 'day $i at $scale');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
