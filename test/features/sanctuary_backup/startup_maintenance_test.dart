import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/router/app_router.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/sanctuary_backup/backup_config.dart';
import 'package:glass/main.dart';
import 'package:go_router/go_router.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

/// A single trivial route so the test boots the REAL [GlassApp] (the widget
/// that owns the post-frame maintenance hook) without dragging the weather
/// stack (HTTP client, geolocation, sky animation) into the test harness.
Override _stubRouter() => appRouterProvider.overrideWith(
      (ref) => GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      ]),
    );

/// The silent app-open freshness net (BACKUP_RETENTION_SPEC §3): booting
/// [GlassApp] with a set-up identity and an empty (therefore stale) vault
/// must take a freshness snapshot, without blocking or surfacing anything.
void main() {
  testWidgets(
      'GlassApp boot runs startup maintenance — an empty vault gains a '
      'freshness snapshot when a key exists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryVaultStore();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        _stubRouter(),
        appDatabaseProvider.overrideWithValue(db),
        sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
        sanctuaryBackupConfigProvider.overrideWithValue(glassBackupConfig),
        backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
        secureKeyStoreProvider.overrideWithValue(
            InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true)),
        cryptoServiceProvider
            .overrideWithValue(FakeCryptoService(mnemonic: _validPhrase)),
        vaultStoreProvider.overrideWithValue(vault),
      ],
      child: const GlassApp(),
    ));

    // Let the post-frame hook fire and its async export/save chain finish.
    for (var i = 0; i < 20 && (await vault.list()).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final entries = await vault.list();
    expect(entries, hasLength(1),
        reason: 'boot must vault a freshness snapshot when none exists');
    expect(entries.single.label, VaultLabel.freshness);
  });

  testWidgets('GlassApp boot takes NO snapshot when no key exists (ghost)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryVaultStore();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        _stubRouter(),
        appDatabaseProvider.overrideWithValue(db),
        sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
        sanctuaryBackupConfigProvider.overrideWithValue(glassBackupConfig),
        backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
        secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
        cryptoServiceProvider
            .overrideWithValue(FakeCryptoService(mnemonic: _validPhrase)),
        vaultStoreProvider.overrideWithValue(vault),
      ],
      child: const GlassApp(),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(await vault.list(), isEmpty,
        reason: 'a ghost-state boot must never mint key material or vault');
  });
}
