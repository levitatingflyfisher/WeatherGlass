// lib/features/settings/settings_controller.dart
import 'package:openhearth_design/openhearth_design.dart';
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
  @override
  GlassSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return GlassSettings(
      units: UnitSystem.fromName(p.getString(SettingsPrefsKeys.units)),
      precision:
          LocationPrecision.fromName(p.getString(SettingsPrefsKeys.precision)),
      theme: OhThemeModePreference.fromStorage(
          p.getString(SettingsPrefsKeys.themeMode)),
    );
  }

  Future<void> setUnits(UnitSystem u) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(SettingsPrefsKeys.units, u.name);
    state = state.copyWith(units: u);
  }

  Future<void> setPrecision(LocationPrecision p) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(SettingsPrefsKeys.precision, p.name);
    // Lowering precision is a privacy action: coarsen the rows already on disk
    // and drop their cached payloads (which embed the finer coordinate) BEFORE
    // announcing the new state, so the recomputed forecasts read coarse rows.
    // The send boundary re-rounds too, but the promise covers the DB itself.
    await ref.read(locationsRepositoryProvider).reRoundAll(p);
    state = state.copyWith(precision: p);
  }

  Future<void> setTheme(OhThemeModePreference t) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(SettingsPrefsKeys.themeMode, t.storageValue);
    state = state.copyWith(theme: t);
  }
}
