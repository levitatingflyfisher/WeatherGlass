import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart' show BackupFormatException;
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late GlassBackupSerializer serializer;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    serializer = GlassBackupSerializer(db, prefs);
  });

  tearDown(() => db.close());

  Future<void> seedLocation({String id = 'L1'}) async {
    await db.into(db.savedLocations).insert(SavedLocationsCompanion.insert(
          id: id,
          label: 'Berlin',
          sublabel: const Value('Germany'),
          lat: 52.52,
          lon: 13.41,
          isCurrent: const Value(false),
          sortOrder: const Value(0),
          createdAt: 1000,
        ));
  }

  group('BackupSerializer', () {
    test('dumpAll carries app + schemaVersion envelope', () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(json['app'], equals('weatherglass'));
      expect(json['schemaVersion'], equals(db.schemaVersion));
      expect(json['exportedAt'], isNotNull);
    });

    test('dumpAll includes saved locations', () async {
      await seedLocation();
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final tables = json['tables'] as Map<String, dynamic>;
      final locations =
          (tables['savedLocations'] as List).cast<Map<String, dynamic>>();

      expect(locations, hasLength(1));
      expect(locations.single['id'], equals('L1'));
      expect(locations.single['label'], equals('Berlin'));
      expect(locations.single['lat'], equals(52.52));
    });

    test('dumpAll never includes ForecastCache — disposable derived data',
        () async {
      await seedLocation();
      await db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
            locationId: 'L1',
            payload: '{"raw":"open-meteo json"}',
            fetchedAt: 1000,
          ));

      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final tables = json['tables'] as Map<String, dynamic>;

      expect(tables.containsKey('forecastCache'), isFalse);
      expect(jsonEncode(json), isNot(contains('open-meteo json')));
    });

    test('dumpAll includes a settings snapshot', () async {
      await prefs.setString(SettingsPrefsKeys.units, 'imperial');
      await prefs.setString(SettingsPrefsKeys.precision, 'precise');
      await prefs.setString(SettingsPrefsKeys.themeMode, 'dark');

      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final settings = json['settings'] as Map<String, dynamic>;

      expect(settings['units'], equals('imperial'));
      expect(settings['precision'], equals('precise'));
      expect(settings['themeMode'], equals('dark'));
    });

    test('restoreAll round-trips saved locations', () async {
      await seedLocation();
      final bytes = await serializer.dumpAll();

      await serializer.restoreAll(bytes);

      final locations = await db.select(db.savedLocations).get();
      expect(locations, hasLength(1));
      expect(locations.single.id, equals('L1'));
      expect(locations.single.label, equals('Berlin'));
      expect(locations.single.lat, equals(52.52));
      expect(locations.single.sublabel, equals('Germany'));
    });

    test('restoreAll round-trips settings', () async {
      await prefs.setString(SettingsPrefsKeys.units, 'imperial');
      await prefs.setString(SettingsPrefsKeys.precision, 'precise');
      await prefs.setString(SettingsPrefsKeys.themeMode, 'dark');
      final bytes = await serializer.dumpAll();

      // Simulate a fresh device with defaults before restoring.
      await prefs.remove(SettingsPrefsKeys.units);
      await prefs.remove(SettingsPrefsKeys.precision);
      await prefs.remove(SettingsPrefsKeys.themeMode);

      await serializer.restoreAll(bytes);

      expect(prefs.getString(SettingsPrefsKeys.units), equals('imperial'));
      expect(prefs.getString(SettingsPrefsKeys.precision), equals('precise'));
      expect(prefs.getString(SettingsPrefsKeys.themeMode), equals('dark'));
    });

    test('restoreAll wipes existing locations before inserting', () async {
      await seedLocation(id: 'old');

      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final serializer2 = GlassBackupSerializer(db2, prefs2);
      await db2.into(db2.savedLocations).insert(SavedLocationsCompanion.insert(
            id: 'new',
            label: 'Tokyo',
            lat: 35.68,
            lon: 139.76,
            createdAt: 2000,
          ));
      final otherDump = await serializer2.dumpAll();

      await serializer.restoreAll(otherDump);

      final locations = await db.select(db.savedLocations).get();
      expect(locations.map((l) => l.id).toSet(), {'new'});
    });

    test('restoreAll clears the forecast cache (it is not part of the backup)',
        () async {
      await seedLocation();
      await db.into(db.forecastCache).insert(ForecastCacheCompanion.insert(
            locationId: 'L1',
            payload: '{}',
            fetchedAt: 1000,
          ));
      final bytes = await serializer.dumpAll();

      await serializer.restoreAll(bytes);

      final cache = await db.select(db.forecastCache).get();
      expect(cache, isEmpty);
    });

    test('restoreAll rejects a backup from a different app', () async {
      final payload = jsonEncode({
        'app': 'lullaby',
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': {'savedLocations': <dynamic>[]},
        'settings': <String, dynamic>{},
      });
      final bytes = Uint8List.fromList(utf8.encode(payload));

      expect(
        () => serializer.restoreAll(bytes),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('restoreAll rejects a future schema version', () async {
      final payload = jsonEncode({
        'app': 'weatherglass',
        'schemaVersion': 999,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': {'savedLocations': <dynamic>[]},
        'settings': <String, dynamic>{},
      });
      final bytes = Uint8List.fromList(utf8.encode(payload));

      expect(
        () => serializer.restoreAll(bytes),
        throwsA(isA<BackupSchemaException>()),
      );
    });

    test('restoreAll rejects missing schemaVersion', () async {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'weatherglass',
        'tables': {'savedLocations': <dynamic>[]},
        'settings': <String, dynamic>{},
      })));

      expect(
        () => serializer.restoreAll(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('restoreAll rejects missing tables key', () async {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'weatherglass',
        'schemaVersion': 1,
        'settings': <String, dynamic>{},
      })));

      expect(
        () => serializer.restoreAll(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('restoreAll rejects missing settings key', () async {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'weatherglass',
        'schemaVersion': 1,
        'tables': {'savedLocations': <dynamic>[]},
      })));

      expect(
        () => serializer.restoreAll(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('a rejected restore never touches existing data (fail closed)',
        () async {
      await seedLocation();
      await prefs.setString(SettingsPrefsKeys.units, 'imperial');

      final badPayload = jsonEncode({
        'app': 'weatherglass',
        'schemaVersion': 999,
        'tables': {'savedLocations': <dynamic>[]},
        'settings': {'units': 'metric'},
      });
      final bytes = Uint8List.fromList(utf8.encode(badPayload));

      await expectLater(
        () => serializer.restoreAll(bytes),
        throwsA(isA<BackupSchemaException>()),
      );

      final locations = await db.select(db.savedLocations).get();
      expect(locations, hasLength(1), reason: 'original data must survive');
      expect(prefs.getString(SettingsPrefsKeys.units), equals('imperial'),
          reason: 'original settings must survive');
    });
  });
}
