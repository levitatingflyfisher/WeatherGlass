import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/presentation/privacy_screen.dart';
import 'package:glass/features/settings/presentation/settings_screen.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';
import 'package:glass/features/weather/presentation/locations_screen.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loc = SavedLocation(
  id: 'berlin',
  label: 'Berlin',
  sublabel: null,
  lat: 52.52,
  lon: 13.41,
  isCurrent: false,
  sortOrder: 0,
  createdAt: 0,
);

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

Future<void> _pump(WidgetTester tester, Widget home,
    {List<SavedLocation> places = const [_loc],
    Size size = const Size(1024, 800)}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider
          .overrideWith((_) => AppDatabase(NativeDatabase.memory())),
      savedLocationsProvider.overrideWith((ref) => Stream.value(places)),
      forecastProvider(_loc.id).overrideWith((ref) => _forecast()),
      secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
      cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
      sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
      sanctuaryBackupConfigProvider.overrideWithValue(const SanctuaryBackupConfig(
          appId: 'weatherglass',
          aadContext: 'weatherglass-backup/v1',
          appDisplayName: 'WeatherGlass')),
      backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
      backupReminderStoreProvider
          .overrideWithValue(InMemoryBackupReminderStore()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await tester.pumpAndSettle();
}

void _expectCapped(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  expect(r.left, greaterThanOrEqualTo((1024 - OhPage.phoneMaxWidth) / 2),
      reason: 'content is centred in a ${OhPage.phoneMaxWidth} column');
  expect(r.right, lessThanOrEqualTo((1024 + OhPage.phoneMaxWidth) / 2));
}

void main() {
  group('at 1024 dp the phone layout is capped, not stretched', () {
    testWidgets('Settings', (tester) async {
      await _pump(tester, const SettingsScreen());
      _expectCapped(tester, find.byType(SegmentedButton<OhThemeModePreference>));
    });
    testWidgets('What leaves your device', (tester) async {
      await _pump(tester, const PrivacyScreen());
      _expectCapped(tester, find.textContaining('local-first'));
      // The prose screen is narrower still.
      expect(tester.getSize(find.textContaining('local-first')).width,
          lessThanOrEqualTo(560));
    });
    testWidgets('Places', (tester) async {
      await _pump(tester, const LocationsScreen());
      _expectCapped(tester, find.byType(ListTile).first);
    });
    testWidgets('Home: the forecast column is capped, the sky is not',
        (tester) async {
      await _pump(tester, const HomeScreen());
      _expectCapped(tester, find.text('Berlin').first);
      _expectCapped(tester, find.byType(Table));
      // The sky still fills the window edge to edge (no hard edge at 760).
      final sky = find.byWidgetPredicate((w) =>
          w is AnimatedContainer && w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient != null);
      expect(tester.getSize(sky.first).width, 1024);
    });
  });

  group('the theme is at most two taps from Home', () {
    testWidgets('with a forecast showing', (tester) async {
      await _pump(tester, const HomeScreen(), size: const Size(360, 740));
      expect(find.byType(OhThemeToggle), findsOneWidget);
    });
    testWidgets('on Places too', (tester) async {
      await _pump(tester, const LocationsScreen(), size: const Size(360, 740));
      expect(find.byType(OhThemeToggle), findsOneWidget);
    });
        testWidgets('on first run, before any place is saved', (tester) async {
      await _pump(tester, const HomeScreen(),
          places: const [], size: const Size(360, 740));
      expect(find.byType(OhThemeToggle), findsOneWidget);
    });
  });

  group('top-bar controls carry visible words, not just tooltips', () {
    for (final empty in [false, true]) {
      testWidgets('Home${empty ? ' (first run)' : ''}', (tester) async {
        await _pump(tester, const HomeScreen(),
            places: empty ? const [] : const [_loc],
            size: const Size(360, 740));
        for (final word in ['Places', 'Settings']) {
          final f = find.text(word);
          expect(f, findsOneWidget, reason: word);
          final button = find.ancestor(of: f, matching: find.byType(InkWell));
          expect(tester.getSize(button.first).height,
              greaterThanOrEqualTo(48), reason: '$word tap target');
        }
      });
    }
    testWidgets('Places: Add is a word', (tester) async {
      await _pump(tester, const LocationsScreen(), size: const Size(360, 740));
      expect(find.descendant(
              of: find.byType(AppBar), matching: find.text('Add')),
          findsOneWidget);
    });
  });

  // The forecast is padded to clear the overlay by the overlay's measured
  // height, which must not include the bottom inset (a gesture bar).
  testWidgets('Home clears the overlay by its top-only height',
      (tester) async {
    Future<double> insetWith(double bottom) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLocationsProvider.overrideWith((ref) => Stream.value([_loc])),
          forecastProvider(_loc.id).overrideWith((ref) => _forecast()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
                padding: EdgeInsets.only(top: 24, bottom: bottom),
                viewPadding: EdgeInsets.only(top: 24, bottom: bottom)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      return tester.widget<ForecastView>(find.byType(ForecastView)).topInset;
    }

    final none = await insetWith(0);
    final gestureBar = await insetWith(48);
    expect(gestureBar, none);
    expect(none, greaterThan(24 + 48 - 1), reason: 'status bar + one row');
  });

  // Follow-up: the city tabs sat in a fixed 38 dp strip, so at large text
  // the names outgrew their pills. They grow with the text now.
  testWidgets('city tabs grow with the text instead of clipping',
      (tester) async {
    const london = SavedLocation(
        id: 'london',
        label: 'London',
        sublabel: null,
        lat: 51.5,
        lon: -0.1,
        isCurrent: false,
        sortOrder: 1,
        createdAt: 0);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        savedLocationsProvider
            .overrideWith((ref) => Stream.value(const [_loc, london])),
        forecastProvider(_loc.id).overrideWith((ref) => _forecast()),
        forecastProvider(london.id).overrideWith((ref) => _forecast()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!),
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final name = find.text('London');
    final pill = find.ancestor(of: name, matching: find.byType(AnimatedContainer));
    expect(pill, findsWidgets);
    // A paragraph squeezed shorter than its text still reports a rect
    // inside the pill while its glyphs spill out, so compare the height it
    // got with the height its text needs.
    final para = tester.renderObject<RenderBox>(name);
    final needs = para.getMinIntrinsicHeight(para.size.width);
    expect(para.size.height, greaterThanOrEqualTo(needs - 0.5),
        reason: 'the name got less height than its text needs');
    expect(tester.takeException(), isNull);
  });
}
