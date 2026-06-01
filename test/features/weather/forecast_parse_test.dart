import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

// Parses a REAL Open-Meteo response (captured live, 7 forecast days). This is
// the single parse the whole app rides on; the goldens use hand-built fakes and
// would miss a schema drift, so guard the real shape here.
void main() {
  late Forecast forecast;

  setUpAll(() {
    final raw = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    forecast = Forecast.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('current conditions parse into usable values', () {
    final c = forecast.current;
    expect(c.temperatureC, isA<double>());
    expect(c.temperatureC.isFinite, isTrue);
    expect(c.humidity, inInclusiveRange(0, 100));
    expect([true, false], contains(c.isDay));
    // The weather code maps to a real condition (no throw, no surprise).
    expect(WeatherCondition.values, contains(c.condition));
  });

  test('daily has 7 days with sane highs/lows and parsed sun times', () {
    expect(forecast.daily.length, 7);
    final d0 = forecast.daily.first;
    expect(d0.highC, greaterThanOrEqualTo(d0.lowC));
    expect(d0.sunrise, isNotNull);
    expect(d0.sunset, isNotNull);
    expect(d0.sunset!.isAfter(d0.sunrise!), isTrue);
  });

  test('hourly covers the 7 forecast days (168 points) in order', () {
    expect(forecast.hourly.length, 7 * 24);
    expect(forecast.hourly.first.time.isBefore(forecast.hourly.last.time),
        isTrue);
    expect(forecast.hourly.first.precipProbability, inInclusiveRange(0, 100));
  });

  test('timezone offset is carried through', () {
    expect(forecast.utcOffsetSeconds, isA<int>());
  });
}
