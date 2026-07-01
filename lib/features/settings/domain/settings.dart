// lib/features/settings/domain/settings.dart
import 'package:flutter/material.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/units.dart';

/// The [SharedPreferences] keys backing [GlassSettings] — a single source of
/// truth shared by [Settings] (which reads/writes them) and the encrypted
/// backup serializer (which must restore to the exact same keys).
abstract final class SettingsPrefsKeys {
  static const units = 'units';
  static const precision = 'precision';
  static const themeMode = 'themeMode';
}

/// The household's preferences. All local; nothing leaves the device, and none
/// of these alter the request shape sent to the provider.
@immutable
class GlassSettings {
  const GlassSettings({
    required this.units,
    required this.precision,
    required this.themeMode,
  });

  final UnitSystem units;
  final LocationPrecision precision;
  final ThemeMode themeMode;

  static const initial = GlassSettings(
    units: UnitSystem.metric,
    precision: LocationPrecision.balanced,
    themeMode: ThemeMode.system,
  );

  GlassSettings copyWith({
    UnitSystem? units,
    LocationPrecision? precision,
    ThemeMode? themeMode,
  }) =>
      GlassSettings(
        units: units ?? this.units,
        precision: precision ?? this.precision,
        themeMode: themeMode ?? this.themeMode,
      );
}

ThemeMode themeModeFromName(String? name) => ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
