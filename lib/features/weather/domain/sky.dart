// lib/features/weather/domain/sky.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

/// The palette of an actual sky: a top→bottom gradient plus the ink colour that
/// reads on it. WeatherGlass's signature is that the whole hero is painted from the
/// *real* current condition and time of day, so the screen looks like the sky
/// outside the window.
@immutable
class SkyPalette {
  const SkyPalette(this.gradient, this.ink, {this.dim});

  /// Two-or-more stops, top of the sky first.
  final List<Color> gradient;

  /// Foreground colour that contrasts with the gradient (text + icons).
  final Color ink;

  /// A muted variant of [ink] for secondary text; derived if omitted.
  final Color? dim;

  /// Secondary text colour: [ink] moved toward the sky by as much as it can
  /// go while still reaching 4.5:1 against every stop of the gradient, and
  /// opaque, so its contrast does not depend on what it is painted over.
  /// (It was ink at alpha 0.72, which failed on the lower stops of its own
  /// gradient: audit mind-in-mind-06.) Pinned by sky_contrast_test.dart.
  Color get dimInk {
    if (dim != null) return dim!;
    final mid = Color.lerp(top, bottom, 0.5)!;
    for (var t = 0.28; t > 0; t -= 0.02) {
      final c = Color.lerp(ink, mid, t)!;
      if (gradient.every((stop) => _contrast(c, stop) >= 4.5)) return c;
    }
    return ink;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// The ground for panels on the sky (detail chips, the 7-day card, the
  /// stale notice) and the wash under the hourly curve: frosted white on a
  /// bright sky, smoked black on a dark one. It moves the ground AWAY from
  /// the ink, so text on a panel is never harder to read than on the bare
  /// sky; an ink-coloured tint pulled it toward the text and below 4.5:1.
  Color get panel => _inkIsDark
      ? Colors.white.withValues(alpha: 0.24)
      : Colors.black.withValues(alpha: 0.22);

  /// The same frost at full strength, for the hourly wash's gradient.
  Color get panelTint => _inkIsDark ? Colors.white : Colors.black;

  bool get _inkIsDark =>
      ThemeData.estimateBrightnessForColor(ink) == Brightness.dark;

  Color get top => gradient.first;
  Color get bottom => gradient.last;

  /// Whether this is a dark sky (night / storm) — callers use it to pick a
  /// matching status-bar brightness.
  bool get isDark =>
      ThemeData.estimateBrightnessForColor(bottom) == Brightness.dark;
}

/// How dark the frosted chips over the sky are (black at this alpha). White
/// labels on them reach 4.5:1 over the top stop of every sky; at the old
/// 0.20 they fell to 3.8:1 over fog. Pinned by sky_contrast_test.dart.
const frostedChipAlpha = 0.32;

/// The frosted chip colour for the selected city tab: darker than
/// [frostedChipAlpha], so selection reads without dimming the others' words.
const frostedChipSelectedAlpha = 0.46;

const _lightInk = Color(0xFF15233A); // deep slate-navy ink on bright skies
const _darkInk = Color(0xFFF3F6FB); // near-white ink on dark skies

/// The sky for a condition at a given time of day. Pure — same inputs always
/// give the same palette, which is what makes it testable and the hero
/// deterministic.
SkyPalette skyFor(WeatherCondition condition, bool isDay) {
  // Night first: a calm condition still gets a starlit-blue, weather darkens it.
  if (!isDay) {
    return switch (condition) {
      WeatherCondition.clear ||
      WeatherCondition.mainlyClear =>
        const SkyPalette([Color(0xFF0B1733), Color(0xFF233A63)], _darkInk),
      WeatherCondition.partlyCloudy =>
        const SkyPalette([Color(0xFF12203D), Color(0xFF2C3E5E)], _darkInk),
      WeatherCondition.thunderstorm ||
      WeatherCondition.thunderstormHail =>
        const SkyPalette([Color(0xFF0C0A1A), Color(0xFF2A2540)], _darkInk),
      WeatherCondition.snow ||
      WeatherCondition.snowGrains ||
      WeatherCondition.snowShowers =>
        const SkyPalette([Color(0xFF1B2438), Color(0xFF3B4A66)], _darkInk),
      _ => const SkyPalette([Color(0xFF11151F), Color(0xFF2A3140)], _darkInk),
    };
  }
  // Daytime skies. Each stop is only as light (or dark) as it can be while
  // its ink still reaches 4.5:1 on it (sky_contrast_test.dart).
  return switch (condition) {
    WeatherCondition.clear =>
      const SkyPalette([Color(0xFF4B8FD5), Color(0xFF8FC2EE)], _lightInk),
    WeatherCondition.mainlyClear =>
      const SkyPalette([Color(0xFF518FCF), Color(0xFFA6CDED)], _lightInk),
    WeatherCondition.partlyCloudy =>
      const SkyPalette([Color(0xFF5C8DBE), Color(0xFFBFD2E0)], _lightInk),
    WeatherCondition.overcast =>
      const SkyPalette([Color(0xFF8C9CAB), Color(0xFFC9D2D9)], _lightInk),
    WeatherCondition.fog =>
      const SkyPalette([Color(0xFF9AA3A8), Color(0xFFD2D6D7)], _lightInk),
    WeatherCondition.drizzle ||
    WeatherCondition.freezingDrizzle =>
      const SkyPalette([Color(0xFF7A8E9C), Color(0xFFAEBEC8)], _lightInk),
    WeatherCondition.rain ||
    WeatherCondition.freezingRain ||
    WeatherCondition.showers =>
      const SkyPalette([Color(0xFF4B6173), Color(0xFF597282)], _darkInk),
    WeatherCondition.snow ||
    WeatherCondition.snowGrains ||
    WeatherCondition.snowShowers =>
      const SkyPalette([Color(0xFF93A6BC), Color(0xFFDCE6F0)], _lightInk),
    WeatherCondition.thunderstorm ||
    WeatherCondition.thunderstormHail =>
      const SkyPalette([Color(0xFF3A4257), Color(0xFF696F81)], _darkInk),
  };
}
