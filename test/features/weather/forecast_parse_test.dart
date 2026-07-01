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

  // Open-Meteo's parallel arrays are untrusted input: a provider-side hiccup
  // that ships one array shorter than its time axis must degrade to a shorter
  // forecast, not a RangeError that (cached!) re-throws on every launch.
  group('length-mismatched parallel arrays (truncated fixture)', () {
    Map<String, dynamic> loadFixture() {
      final raw = File('test/features/weather/fixtures/forecast_berlin.json')
          .readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    test('a short hourly value array clamps instead of throwing', () {
      final j = loadFixture();
      final h = j['hourly'] as Map<String, dynamic>;
      final temps = (h['temperature_2m'] as List).toList()..removeLast();
      h['temperature_2m'] = temps; // 168 times, 167 temps
      final f = Forecast.fromJson(j);
      expect(f.hourly.length, temps.length,
          reason: 'clamp to the shortest array — never index past it');
    });

    test('a short daily value array clamps instead of throwing', () {
      final j = loadFixture();
      final d = j['daily'] as Map<String, dynamic>;
      final maxes = (d['temperature_2m_max'] as List).toList()..removeLast();
      d['temperature_2m_max'] = maxes; // 7 days, 6 highs
      final f = Forecast.fromJson(j);
      expect(f.daily.length, maxes.length,
          reason: 'clamp to the shortest array — never index past it');
    });

    test('short sunrise/sunset arrays leave the tail days sunless, no throw',
        () {
      final j = loadFixture();
      final d = j['daily'] as Map<String, dynamic>;
      final sunrises = (d['sunrise'] as List).toList()..removeLast();
      d['sunrise'] = sunrises; // optional array shorter than the time axis
      final f = Forecast.fromJson(j);
      expect(f.daily.length, 7);
      expect(f.daily.last.sunrise, isNull,
          reason: 'a missing optional value degrades to null, not RangeError');
      expect(f.daily.first.sunrise, isNotNull);
    });
  });
}
