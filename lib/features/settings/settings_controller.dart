// lib/features/settings/settings_controller.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/units.dart';

part 'settings_controller.g.dart';

/// Reads preferences synchronously from the SharedPreferences seeded in main(),
/// and persists each change. Backed by prefs (not the DB) because settings are
/// tiny key→values and want a synchronous first read for a flicker-free launch.
@riverpod
class Settings extends _$Settings {
  static const _kUnits = 'units';
  static const _kPrecision = 'precision';
  static const _kTheme = 'themeMode';

  @override
  GlassSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return GlassSettings(
      units: UnitSystem.fromName(p.getString(_kUnits)),
      precision: LocationPrecision.fromName(p.getString(_kPrecision)),
      themeMode: themeModeFromName(p.getString(_kTheme)),
    );
  }

  Future<void> setUnits(UnitSystem u) async {
    await ref.read(sharedPreferencesProvider).setString(_kUnits, u.name);
    state = state.copyWith(units: u);
  }

  Future<void> setPrecision(LocationPrecision p) async {
    await ref.read(sharedPreferencesProvider).setString(_kPrecision, p.name);
    state = state.copyWith(precision: p);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await ref.read(sharedPreferencesProvider).setString(_kTheme, m.name);
    state = state.copyWith(themeMode: m);
  }
}
