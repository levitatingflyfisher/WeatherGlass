import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/domain/sky.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Text on the living sky must be readable at every point of it, top and
/// bottom stop alike (WCAG AA, 4.5:1 for body text). audit mind-in-mind-06:
/// dimInk was ink at alpha 0.72, which failed against the lower stops of its
/// own gradient; and several daytime skies failed even for full ink at the
/// top (clear 3.5:1) or bottom (rain 2.4:1).
void main() {
  for (final c in WeatherCondition.values) {
    for (final isDay in [true, false]) {
      final s = skyFor(c, isDay);
      final name = '${c.name} ${isDay ? 'day' : 'night'}';
      test('$name: ink and dimInk reach 4.5:1 on every stop', () {
        for (final stop in s.gradient) {
          expect(_contrast(s.ink, stop), greaterThanOrEqualTo(4.5),
              reason: '$name ink on $stop');
          expect(_contrast(s.dimInk, stop), greaterThanOrEqualTo(4.5),
              reason: '$name dimInk on $stop');
        }
        // Text also sits on panels over the sky (the detail chips, the
        // 7-day card, the stale notice) and on the wash under the hourly
        // curve (panelTint at up to 0.28). Those grounds must not pull the
        // contrast below the bare sky's.
        for (final stop in s.gradient) {
          for (final ground in [
            Color.alphaBlend(s.panel, stop),
            Color.alphaBlend(s.panelTint.withValues(alpha: 0.28), stop),
          ]) {
            expect(_contrast(s.ink, ground), greaterThanOrEqualTo(4.5),
                reason: '$name ink on a panel over $stop');
            expect(_contrast(s.dimInk, ground), greaterThanOrEqualTo(4.5),
                reason: '$name dimInk on a panel over $stop');
          }
        }
        expect(s.dimInk.a, 1.0,
            reason: 'dimInk is opaque, so its contrast does not depend on '
                'what it happens to be painted over');
      });
    }
  }

  test('white labels on the frosted chips reach 4.5:1 over every sky top', () {
    for (final c in WeatherCondition.values) {
      for (final isDay in [true, false]) {
        final top = skyFor(c, isDay).top;
        for (final alpha in [frostedChipAlpha, frostedChipSelectedAlpha]) {
          final chip =
              Color.alphaBlend(Colors.black.withValues(alpha: alpha), top);
          expect(_contrast(Colors.white, chip), greaterThanOrEqualTo(4.5),
              reason: '${c.name} ${isDay ? 'day' : 'night'} at $alpha');
        }
      }
    }
  });
}
