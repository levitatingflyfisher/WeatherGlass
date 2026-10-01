// lib/features/settings/domain/settings.dart
import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/units.dart';

/// The [SharedPreferences] keys backing [GlassSettings] — a single source of
/// truth shared by [Settings] (which reads/writes them) and the encrypted
/// backup serializer (which must restore to the exact same keys).
abstract final class SettingsPrefsKeys {
  static const units = 'units';
  static const precision = 'precision';
  static const themeMode = 'themeMode';

  /// The saved place Home showed last, so a relaunch opens on it.
  static const lastPlaceId = 'lastPlaceId';
}

/// The household's preferences. All local; nothing leaves the device, and none
/// of these alter the request shape sent to the provider.
@immutable
class GlassSettings {
  const GlassSettings({
    required this.units,
    required this.precision,
    required this.theme,
  });

  final UnitSystem units;
  final LocationPrecision precision;
  /// Light, dark, or follow the phone (the fleet default). Stored as its
  /// [OhThemeModePreference.storageValue], which is the same string the app
  /// stored as a ThemeMode name before, so nothing needs migrating.
  final OhThemeModePreference theme;

  ThemeMode get themeMode => theme.themeMode;

  static const initial = GlassSettings(
    units: UnitSystem.metric,
    precision: LocationPrecision.balanced,
    theme: OhThemeModePreference.defaultValue,
  );

  GlassSettings copyWith({
    UnitSystem? units,
    LocationPrecision? precision,
    OhThemeModePreference? theme,
  }) =>
      GlassSettings(
        units: units ?? this.units,
        precision: precision ?? this.precision,
        theme: theme ?? this.theme,
      );
}
