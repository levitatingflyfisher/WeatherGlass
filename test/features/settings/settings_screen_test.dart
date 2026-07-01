// Widget tests for SettingsScreen's new "Backup & Restore" section
// (SANCTUARY-BRIEF §4.W2) — renders correctly and survives the fleet's
// accessibility sweep (320dp width x 3.0 text scale) in both the ghost state
// and the key-set-up state, which adds more tiles.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/presentation/settings_screen.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ackedMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

Future<Widget> _makeScreen({
  required SecureKeyStore store,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      appDatabaseProvider
          .overrideWith((_) => AppDatabase(NativeDatabase.memory())),
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureKeyStoreProvider.overrideWithValue(store),
      cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
      sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
      sanctuaryBackupConfigProvider.overrideWithValue(
        const SanctuaryBackupConfig(
          appId: 'weatherglass',
          aadContext: 'weatherglass-backup/v1',
          appDisplayName: 'WeatherGlass',
        ),
      ),
      backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  group('SettingsScreen — Backup & Restore section', () {
    testWidgets('sits between Privacy & data and About, ghost state',
        (tester) async {
      await tester.pumpWidget(await _makeScreen(store: InMemorySecureKeyStore()));
      await tester.pumpAndSettle();

      expect(find.text('BACKUP & RESTORE'), findsOneWidget);
      expect(find.text('Set up encrypted backup'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
      // The other settings sections are unaffected — PRIVACY & DATA is
      // above the fold; ABOUT needs a scroll now that Backup & Restore adds
      // height between them, so scroll to confirm it's still reachable
      // rather than accidentally pushed off the ListView entirely.
      expect(find.text('PRIVACY & DATA'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ABOUT'), 300);
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('shows export once the seed is acknowledged', (tester) async {
      await tester.pumpWidget(await _makeScreen(
        store: InMemorySecureKeyStore(
            mnemonic: _ackedMnemonic, acknowledged: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export backup'), findsOneWidget);
      expect(find.text('Reset identity'), findsOneWidget);
    });

    testWidgets('no overflow at 320dp x textScale 3.0 (ghost state)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _makeScreen(
        store: InMemorySecureKeyStore(),
        textScale: 3.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at narrow width + large text scale');
    });

    testWidgets(
        'no overflow at 320dp x textScale 3.0 (key set up + acknowledged)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _makeScreen(
        store: InMemorySecureKeyStore(
            mnemonic: _ackedMnemonic, acknowledged: true),
        textScale: 3.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at narrow width + large text scale');
    });
  });
}
