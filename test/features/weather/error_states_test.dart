import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';
import 'package:glass/features/weather/presentation/locations_screen.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What the audit saw on Home: http's ClientException with the whole query.
final _raw = Exception(
    'ClientException: Failed to fetch, uri=https://api.open-meteo.com/v1/'
    'forecast?latitude=52.52&longitude=13.41&current=temperature_2m');

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

Future<void> _pump(WidgetTester tester, Widget home,
    List<Override> overrides) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await tester.pumpAndSettle();
}

void _expectFriendly(WidgetTester tester) {
  expect(find.textContaining('ClientException'), findsNothing);
  expect(find.textContaining('open-meteo.com/v1'), findsNothing);
  expect(find.text('Try again'), findsOneWidget);
}

void main() {
  testWidgets('a forecast that fails to load shows no raw exception',
      (tester) async {
    await _pump(tester, const Scaffold(body: ForecastView(location: _loc)), [
      forecastProvider(_loc.id).overrideWith((ref) => throw _raw),
    ]);
    _expectFriendly(tester);
    expect(find.textContaining('Open-Meteo'), findsWidgets);
  });

  testWidgets('Home shows no raw exception when places fail to load',
      (tester) async {
    await _pump(tester, const HomeScreen(), [
      savedLocationsProvider.overrideWith((ref) => Stream.error(_raw)),
    ]);
    _expectFriendly(tester);
  });

  testWidgets('Places shows no raw exception when places fail to load',
      (tester) async {
    await _pump(tester, const LocationsScreen(), [
      savedLocationsProvider.overrideWith((ref) => Stream.error(_raw)),
    ]);
    _expectFriendly(tester);
  });
}
