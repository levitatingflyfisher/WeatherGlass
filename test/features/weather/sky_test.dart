import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/domain/sky.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

void main() {
  group('skyFor (the living-sky signature)', () {
    test('a clear day and a clear night are different skies', () {
      final day = skyFor(WeatherCondition.clear, true);
      final night = skyFor(WeatherCondition.clear, false);
      expect(day.gradient, isNot(equals(night.gradient)));
      expect(night.isDark, isTrue, reason: 'a clear night is a dark sky');
      expect(day.isDark, isFalse, reason: 'a clear day is a bright sky');
    });

    test('is deterministic — same inputs, same palette', () {
      expect(skyFor(WeatherCondition.rain, true).gradient,
          skyFor(WeatherCondition.rain, true).gradient);
    });

    test('every condition yields a usable gradient and ink', () {
      for (final c in WeatherCondition.values) {
        for (final isDay in [true, false]) {
          final s = skyFor(c, isDay);
          expect(s.gradient.length, greaterThanOrEqualTo(2));
          expect(s.ink, isA<Color>());
          expect(s.dimInk.a, lessThan(s.ink.a + 0.001));
        }
      }
    });

    test('a storm is darker than clear sky in daytime', () {
      double luma(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
      final clear = skyFor(WeatherCondition.clear, true);
      final storm = skyFor(WeatherCondition.thunderstorm, true);
      expect(luma(storm.bottom), lessThan(luma(clear.bottom)));
    });
  });
}
