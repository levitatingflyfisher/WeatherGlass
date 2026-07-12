import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/sanctuary_backup/presentation/backup_settings_section.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

Widget _wrap({
  required SecureKeyStore store,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      secureKeyStoreProvider.overrideWithValue(store),
      // Deterministic + fast — skips real PBKDF2 so tests don't need a
      // multi-second pumpAndSettle to let key derivation finish.
      cryptoServiceProvider
          .overrideWithValue(FakeCryptoService(mnemonic: _validPhrase)),
      sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
      // WeatherGlass's real backup wiring (SANCTUARY-BRIEF §4.W2).
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
      home: Scaffold(
        body: ListView(children: const [GlassBackupSection()]),
      ),
    ),
  );
}

void main() {
  group('GlassBackupSection', () {
    testWidgets('ghost state shows setup + restore, not export',
        (tester) async {
      await tester.pumpWidget(_wrap(store: InMemorySecureKeyStore()));
      await tester.pumpAndSettle();

      expect(find.text('Set up encrypted backup'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
      expect(find.text('Export backup'), findsNothing);
    });

    testWidgets('key + acknowledged shows export + reset', (tester) async {
      await tester.pumpWidget(_wrap(
        store: InMemorySecureKeyStore(
            mnemonic: _validPhrase, acknowledged: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export backup'), findsOneWidget);
      expect(find.text('Reset identity'), findsOneWidget);
      expect(find.text('Set up encrypted backup'), findsNothing);
    });

    testWidgets('export subtitle names what is actually saved', (tester) async {
      await tester.pumpWidget(_wrap(
        store: InMemorySecureKeyStore(
            mnemonic: _validPhrase, acknowledged: true),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Save an encrypted copy of your places and settings'),
        findsOneWidget,
      );
    });

    testWidgets('no overflow at 320 dp x 3.0 text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        store: InMemorySecureKeyStore(
            mnemonic: _validPhrase, acknowledged: true),
        textScale: 3.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
