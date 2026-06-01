// lib/features/settings/domain/settings.dart
import 'package:flutter/material.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/units.dart';

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
