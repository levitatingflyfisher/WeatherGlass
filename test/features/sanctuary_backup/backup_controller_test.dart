import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/sanctuary_backup/backup_config.dart';
import 'package:glass/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end net for WeatherGlass's wiring: the real serializer + real
/// crypto, driven through the package's BackupController with WeatherGlass's
/// actual config (appId 'weatherglass', appDomain 'weatherglass', context
/// 'weatherglass-backup/v1', and [glassBackupConfig]'s real
/// [afterGlassRestore] invalidation set — not a fake flag). The generic
/// controller behaviour (RestoreOutcome mapping, seed flows) is unit-tested
/// in the package; this proves WeatherGlass's wiring works against the real
/// sanctuary_auth_core (SANCTUARY-BRIEF §4.W2).
const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer makeContainer({
    required AppDatabase database,
    required SharedPreferences prefs,
    required SecureKeyStore store,
  }) {
    final c = ProviderContainer(overrides: [
      secureKeyStoreProvider.overrideWithValue(store),
      cryptoServiceProvider.overrideWithValue(const DefaultCryptoService()),
      sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
      appDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      backupSerializerProvider
          .overrideWith((ref) => GlassBackupSerializer(database, prefs)),
      sanctuaryBackupConfigProvider.overrideWithValue(glassBackupConfig),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test(
      'export -> restore round-trips WeatherGlass data and refreshes '
      'settings, places, and the pending city selection', () async {
    await db.into(db.savedLocations).insert(SavedLocationsCompanion.insert(
          id: 'L1',
          label: 'Berlin',
          lat: 52.52,
          lon: 13.41,
          createdAt: 1000,
        ));

    SharedPreferences.setMockInitialValues({
      SettingsPrefsKeys.units: 'imperial',
      SettingsPrefsKeys.precision: 'precise',
      SettingsPrefsKeys.themeMode: 'dark',
    });
    final prefs = await SharedPreferences.getInstance();

    final src = makeContainer(
      database: db,
      prefs: prefs,
      store:
          InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
    );
    final result =
        await src.read(backupControllerProvider.notifier).exportBackup();
    expect(result, isNotNull);
    expect(result!.filename,
        matches(RegExp(r'^weatherglass-backup-\d{4}-\d{2}-\d{2}\.ohbk$')));
    expect(result.bytes.sublist(0, 4), equals([0x4F, 0x48, 0x42, 0x4B]));

    // Restore into a fresh DB, fresh (different) settings, and an empty
    // keychain, by phrase — as a new device or a fresh install would be.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    SharedPreferences.setMockInitialValues({
      SettingsPrefsKeys.units: 'metric',
      SettingsPrefsKeys.precision: 'coarse',
      SettingsPrefsKeys.themeMode: 'light',
    });
    final prefs2 = await SharedPreferences.getInstance();

    final dst = makeContainer(
      database: db2,
      prefs: prefs2,
      store: InMemorySecureKeyStore(),
    );

    // A "jump to this city" request queued just before the restore — must be
    // cleared, not left pointing at a since-wiped id.
    dst.read(selectedCityIdProvider.notifier).state = 'stale-id';
    // Subscribe so a stale cached read (rather than a genuine rebuild) would
    // be caught by asserting on this container's re-read below.
    final settingsSub = dst.listen(settingsProvider, (_, __) {});
    final placesSub = dst.listen(savedLocationsProvider, (_, __) {});
    addTearDown(settingsSub.close);
    addTearDown(placesSub.close);

    final outcome = await dst
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(result.bytes, _validPhrase);
    expect(outcome, RestoreOutcome.success);

    expect(dst.read(selectedCityIdProvider), isNull,
        reason: 'onAfterRestore must clear a stale jump-to-city request');
    expect(dst.read(settingsProvider).units, UnitSystem.imperial);
    expect(dst.read(settingsProvider).precision, LocationPrecision.precise);
    expect(dst.read(settingsProvider).themeMode, ThemeMode.dark);

    final places = await dst.read(savedLocationsProvider.future);
    expect(places.map((l) => l.id).toSet(), {'L1'});
  });

  test('a non-OHBK blob restores as corruptFile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = makeContainer(
        database: db, prefs: prefs, store: InMemorySecureKeyStore());
    final outcome = await c
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(Uint8List.fromList(List.filled(64, 0)), _validPhrase);
    expect(outcome, RestoreOutcome.corruptFile);
  });

  test('a backup encrypted for a different appDomain fails to decrypt',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final src = makeContainer(
      database: db,
      prefs: prefs,
      store:
          InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
    );
    final result =
        await src.read(backupControllerProvider.notifier).exportBackup();

    // ...restoring under no domain (legacy/null) must not silently succeed:
    // the derived key differs, so this is the wrong-phrase path.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
      cryptoServiceProvider.overrideWithValue(const DefaultCryptoService()),
      // No sanctuaryAppDomainProvider override — stays at the null default.
      appDatabaseProvider.overrideWithValue(db2),
      sharedPreferencesProvider.overrideWithValue(prefs2),
      backupSerializerProvider
          .overrideWith((ref) => GlassBackupSerializer(db2, prefs2)),
      sanctuaryBackupConfigProvider.overrideWithValue(glassBackupConfig),
    ]);
    addTearDown(c.dispose);

    final outcome = await c
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(result!.bytes, _validPhrase);

    expect(outcome, RestoreOutcome.wrongPhrase);
  });
}
