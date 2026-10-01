import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// At 360 dp and 2x text the three detail chips sheared their words: the
/// values ellipsized ("12 k…", "0.0 …") and "Humidity" broke mid-word
/// (parked from the rollout). Each chip's value and name must be whole.
void main() {
  for (final scale in [1.0, 1.3, 2.0, 3.0]) {
    testWidgets('detail chips are whole at 360 dp x $scale', (tester) async {
      await _pump(tester, scale);
      expect(tester.takeException(), isNull);
      for (final label in ['Wind', 'Humidity', 'Rain']) {
        final f = find.text(label);
        expect(f, findsOneWidget);
        final p = tester.renderObject<RenderParagraph>(f);
        // One line: the name never breaks mid-word.
        expect(p.getBoxesForSelection(TextSelection(
                baseOffset: 0, extentOffset: label.length))
            .map((b) => b.top.round()).toSet(), hasLength(1),
            reason: '"$label" breaks across lines at $scale');
      }
      for (final value in ['12 km/h', '47%', '0.0 mm']) {
        final f = find.text(value);
        expect(f, findsOneWidget, reason: value);
        expect(tester.renderObject<RenderParagraph>(f).didExceedMaxLines,
            isFalse, reason: '"$value" is cut at $scale');
      }
      if (scale == 1.0) {
        // At everyday sizes they stay one row of three.
        final tops = ['Wind', 'Humidity', 'Rain']
            .map((l) => tester.getTopLeft(find.text(l)).dy.round())
            .toSet();
        expect(tops, hasLength(1));
      }
    });
  }
}
