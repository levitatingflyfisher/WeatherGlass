import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedLocation _place(String id, String label, int order) => SavedLocation(
      id: id,
      label: label,
      sublabel: null,
      lat: 52.52,
      lon: 13.41,
      isCurrent: false,
      sortOrder: order,
      createdAt: 0,
    );

final _places = [
  _place('berlin', 'Berlin', 0),
  _place('paris', 'Paris', 1),
  _place('oslo', 'Oslo', 2),
];

Forecast _forecast() {
  final base = DateTime(2026, 6, 25);
  return Forecast(
    current: CurrentConditions(
        time: DateTime(2026, 6, 25, 14),
        temperatureC: 23.6,
        apparentC: 24.8,
        weatherCode: 0,
        isDay: true,
        windKmh: 12,
        humidity: 47,
        precipMm: 0),
    hourly: [
      for (var i = 0; i < 48; i++)
        HourlyPoint(
            time: base.add(Duration(hours: i)),
            temperatureC: 18,
            precipProbability: 0,
            weatherCode: 0),
    ],
    daily: [
      for (var i = 0; i < 7; i++)
        DailyPoint(
            date: base.add(Duration(days: i)),
            weatherCode: 0,
            highC: 25,
            lowC: 14,
            precipProbabilityMax: 0),
    ],
    utcOffsetSeconds: 7200,
  );
}

Future<void> _pumpHome(WidgetTester tester, SharedPreferences prefs) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    // A fresh scope each time: a relaunch.
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider
          .overrideWith((_) => AppDatabase(NativeDatabase.memory())),
      savedLocationsProvider.overrideWith((ref) => Stream.value(_places)),
      for (final p in _places)
        forecastProvider(p.id).overrideWith((ref) => _forecast()),
      secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
      cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
      sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
      sanctuaryBackupConfigProvider.overrideWithValue(
          const SanctuaryBackupConfig(
              appId: 'weatherglass',
              aadContext: 'weatherglass-backup/v1',
              appDisplayName: 'WeatherGlass')),
      backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
      backupReminderStoreProvider
          .overrideWithValue(InMemoryBackupReminderStore()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
  ));
  await tester.pumpAndSettle();
}

String _shownPlace(WidgetTester tester) {
  final views = tester
      .widgetList<ForecastView>(find.byType(ForecastView).hitTestable())
      .toList();
  expect(views, hasLength(1));
  return views.single.location.id;
}

/// Home always opened on the first place, so someone who lives in their
/// second city swiped every launch (audit about-face-09). It now reopens
/// the place last looked at.
void main() {
  testWidgets('Home reopens on the place last viewed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pumpHome(tester, prefs);
    expect(_shownPlace(tester), 'berlin');

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(_shownPlace(tester), 'paris');

    await _pumpHome(tester, prefs);
    expect(_shownPlace(tester), 'paris');
  });

  testWidgets('a remembered place that is gone falls back to the first',
      (tester) async {
    SharedPreferences.setMockInitialValues({'lastPlaceId': 'atlantis'});
    final prefs = await SharedPreferences.getInstance();
    await _pumpHome(tester, prefs);
    expect(_shownPlace(tester), 'berlin');
  });
}
