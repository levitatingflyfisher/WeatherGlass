// lib/features/weather/domain/sky.dart
import 'package:flutter/material.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

/// The palette of an actual sky: a top→bottom gradient plus the ink colour that
/// reads on it. Glass's signature is that the whole hero is painted from the
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

  Color get dimInk => dim ?? ink.withValues(alpha: 0.72);
  Color get top => gradient.first;
  Color get bottom => gradient.last;

  /// Whether this is a dark sky (night / storm) — callers use it to pick a
  /// matching status-bar brightness.
  bool get isDark =>
      ThemeData.estimateBrightnessForColor(bottom) == Brightness.dark;
}

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
  // Daytime skies.
  return switch (condition) {
    WeatherCondition.clear => const SkyPalette(
        [Color(0xFF2E79C7), Color(0xFF8FC2EE)], _lightInk),
    WeatherCondition.mainlyClear => const SkyPalette(
        [Color(0xFF3D82C9), Color(0xFFA6CDED)], _lightInk),
    WeatherCondition.partlyCloudy => const SkyPalette(
        [Color(0xFF5C8DBE), Color(0xFFBFD2E0)], _lightInk),
    WeatherCondition.overcast => const SkyPalette(
        [Color(0xFF8C9CAB), Color(0xFFC9D2D9)], _lightInk),
    WeatherCondition.fog => const SkyPalette(
        [Color(0xFF9AA3A8), Color(0xFFD2D6D7)], _lightInk),
    WeatherCondition.drizzle ||
    WeatherCondition.freezingDrizzle =>
      const SkyPalette([Color(0xFF6E8493), Color(0xFFAEBEC8)], _lightInk),
    WeatherCondition.rain ||
    WeatherCondition.freezingRain ||
    WeatherCondition.showers =>
      const SkyPalette([Color(0xFF4B6173), Color(0xFF8FA4B2)], _darkInk),
    WeatherCondition.snow ||
    WeatherCondition.snowGrains ||
    WeatherCondition.snowShowers =>
      const SkyPalette([Color(0xFF93A6BC), Color(0xFFDCE6F0)], _lightInk),
    WeatherCondition.thunderstorm ||
    WeatherCondition.thunderstormHail =>
      const SkyPalette([Color(0xFF3A4257), Color(0xFF6B7184)], _darkInk),
  };
}
