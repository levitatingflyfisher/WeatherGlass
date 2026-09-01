import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';
import 'package:glass/features/weather/presentation/locations_screen.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Release gate (roadmap item 24): at 360dp × 1.3 text each primary screen's
/// main action is on screen and tappable (scrolling to it is fine), then the
/// same screen survives 320dp × 3.0 without overflowing. Rendered with the
/// app's real theme, so the 0.7 type ladder (body 16) is what is measured.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // Places come from a plain stream: first run (none saved), so Home's
  // primary action is Add a place.
  Widget app(Widget screen) => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLocationsProvider
              .overrideWith((ref) => Stream.value(const <SavedLocation>[])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      );

  testWidgets('HomeScreen (first run): Add a place reachable at 360dp x 1.3',
      (tester) async {
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () => tester.pumpWidget(app(const HomeScreen())),
      primaryAction: find.text('Add a place'),
    );
  });

  testWidgets('LocationsScreen: Add reachable at 360dp x 1.3', (tester) async {
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () => tester.pumpWidget(app(const LocationsScreen())),
      primaryAction: find.text('Add'),
    );
  });

  testWidgets('AddLocationSheet: search field reachable at 360dp x 1.3',
      (tester) async {
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () => tester.pumpWidget(
          app(const Scaffold(body: SafeArea(child: AddLocationSheet())))),
      primaryAction: find.byType(TextField),
    );
  });
}
