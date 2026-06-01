// lib/features/weather/domain/weather_code.dart
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// A WMO weather-interpretation bucket. Open-Meteo returns a numeric WMO
/// `weather_code`; we collapse the ~28 codes into the conditions a person
/// actually distinguishes, each with a plain label and an icon.
enum WeatherCondition {
  clear('Clear'),
  mainlyClear('Mainly clear'),
  partlyCloudy('Partly cloudy'),
  overcast('Overcast'),
  fog('Fog'),
  drizzle('Drizzle'),
  freezingDrizzle('Freezing drizzle'),
  rain('Rain'),
  freezingRain('Freezing rain'),
  showers('Showers'),
  snow('Snow'),
  snowGrains('Snow grains'),
  snowShowers('Snow showers'),
  thunderstorm('Thunderstorm'),
  thunderstormHail('Thunderstorm, hail');

  const WeatherCondition(this.label);
  final String label;

  /// True for the wet/white conditions — used to decide whether to show a
  /// precipitation chance prominently.
  bool get isPrecipitating => switch (this) {
        clear || mainlyClear || partlyCloudy || overcast || fog => false,
        _ => true,
      };
}

/// Map a WMO weather code to a [WeatherCondition]. Unknown codes fall back to
/// overcast (a safe, neutral default) rather than throwing.
WeatherCondition conditionFromWmo(int code) => switch (code) {
      0 => WeatherCondition.clear,
      1 => WeatherCondition.mainlyClear,
      2 => WeatherCondition.partlyCloudy,
      3 => WeatherCondition.overcast,
      45 || 48 => WeatherCondition.fog,
      51 || 53 || 55 => WeatherCondition.drizzle,
      56 || 57 => WeatherCondition.freezingDrizzle,
      61 || 63 || 65 => WeatherCondition.rain,
      66 || 67 => WeatherCondition.freezingRain,
      71 || 73 || 75 => WeatherCondition.snow,
      77 => WeatherCondition.snowGrains,
      80 || 81 || 82 => WeatherCondition.showers,
      85 || 86 => WeatherCondition.snowShowers,
      95 => WeatherCondition.thunderstorm,
      96 || 99 => WeatherCondition.thunderstormHail,
      _ => WeatherCondition.overcast,
    };

/// The icon for a condition. Clear/partly-cloudy swap between sun and moon
/// glyphs by [isDay]; everything else reads the same day or night.
IconData iconFor(WeatherCondition c, bool isDay) => switch (c) {
      WeatherCondition.clear => isDay ? LucideIcons.sun : LucideIcons.moon,
      WeatherCondition.mainlyClear =>
        isDay ? LucideIcons.sun : LucideIcons.moon,
      WeatherCondition.partlyCloudy =>
        isDay ? LucideIcons.cloudSun : LucideIcons.cloudMoon,
      WeatherCondition.overcast => LucideIcons.cloudy,
      WeatherCondition.fog => LucideIcons.cloudFog,
      WeatherCondition.drizzle => LucideIcons.cloudDrizzle,
      WeatherCondition.freezingDrizzle => LucideIcons.cloudDrizzle,
      WeatherCondition.rain => LucideIcons.cloudRain,
      WeatherCondition.freezingRain => LucideIcons.cloudRainWind,
      WeatherCondition.showers => LucideIcons.cloudRain,
      WeatherCondition.snow => LucideIcons.cloudSnow,
      WeatherCondition.snowGrains => LucideIcons.snowflake,
      WeatherCondition.snowShowers => LucideIcons.cloudSnow,
      WeatherCondition.thunderstorm => LucideIcons.cloudLightning,
      WeatherCondition.thunderstormHail => LucideIcons.cloudHail,
    };
