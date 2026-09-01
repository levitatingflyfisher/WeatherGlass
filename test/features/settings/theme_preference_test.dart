import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The theme is light / dark / follow the phone (openhearth_design's
/// OhThemeModePreference), default follow the phone. WeatherGlass already
/// stored a ThemeMode *name* under 'themeMode' with system as the default,
/// so there is no isDarkMode bool to migrate: the stored strings already
/// equal OhThemeModePreference.storageValue, and a stored 'light' was a
/// deliberate choice. The key and strings must not change — encrypted
/// backups restore exactly this key.
void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(p)]);
    addTearDown(c.dispose);
    return c;
  }

  const cases = <String?, OhThemeModePreference>{
    'light': OhThemeModePreference.light,
    'dark': OhThemeModePreference.dark,
    'system': OhThemeModePreference.system,
    null: OhThemeModePreference.system,
    'garbage': OhThemeModePreference.system,
  };
  for (final e in cases.entries) {
    test('stored ${e.key} reads as ${e.value.name}', () async {
      final c = await containerWith(
          {if (e.key != null) SettingsPrefsKeys.themeMode: e.key!});
      expect(c.read(settingsProvider).theme, e.value);
      expect(c.read(settingsProvider).themeMode, e.value.themeMode);
    });
  }

  test('a choice is stored under the same key the backup restores',
      () async {
    final c = await containerWith({});
    await c.read(settingsProvider.notifier).setTheme(OhThemeModePreference.dark);
    final p = c.read(sharedPreferencesProvider);
    expect(p.getString(SettingsPrefsKeys.themeMode), 'dark');
    expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
  });
}
