import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:glass/features/settings/presentation/privacy_screen.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/weather/domain/geo.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The transparency screen is the app's central claim, so each sentence on
/// it is pinned here (audit checklist-manifesto-02/06, finding 3/4/9).
void main() {
  // A row finer than the setting: what a half-finished re-round, or a row
  // saved under Precise before the user chose Coarse, would leave.
  const fine = SavedLocation(
    id: 'L1',
    label: 'Berlin',
    sublabel: null,
    lat: 52.523,
    lon: 13.413,
    isCurrent: false,
    sortOrder: 0,
    createdAt: 0,
  );
  const other = SavedLocation(
    id: 'L2',
    label: 'Oslo',
    sublabel: null,
    lat: 59.9,
    lon: 10.8,
    isCurrent: false,
    sortOrder: 1,
    createdAt: 0,
  );

  Future<void> pump(WidgetTester tester, LocationPrecision precision,
      {double scale = 1, Size size = const Size(400, 4000)}) async {
    SharedPreferences.setMockInitialValues(
        {SettingsPrefsKeys.precision: precision.name});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        savedLocationsProvider
            .overrideWith((ref) => Stream.value(const [fine, other])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: const PrivacyScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the URL on screen is the URL the app sends', (tester) async {
    // What the send path requests for this row at Coarse.
    Uri? sent;
    final fixture = File('test/features/weather/fixtures/forecast_berlin.json')
        .readAsStringSync();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => WeatherRepository(
            db,
            OpenMeteo(
                client: MockClient((r) async {
              sent = r.url;
              return http.Response(fixture, 200);
            })))
        .getForecast(fine, precision: LocationPrecision.coarse));

    await pump(tester, LocationPrecision.coarse);
    expect(sent, isNotNull);
    expect(find.text(sent.toString()), findsOneWidget,
        reason: 'the displayed request must be built the way the send path '
            'builds it, re-rounded to the current precision');
  });

  testWidgets('the caption is true in both directions', (tester) async {
    await pump(tester, LocationPrecision.precise);
    // The row sits on a finer grid than Oslo, but the claim is a bound.
    expect(
        find.text('This is the entire forecast request for Berlin. The only '
            'part that differs between you and anyone else is the '
            'coordinate, rounded to ~110 m or coarser. There is no key, no '
            'token, and nothing that ties it to you.'),
        findsOneWidget);
    expect(find.textContaining('Applies to places you add from now on'),
        findsNothing);
    expect(
        find.text('How coarsely your location is rounded before it’s stored '
            'or sent. A coarser setting re-rounds every saved place now; a '
            'finer one applies only to places you add afterwards.'),
        findsOneWidget);
  });

  testWidgets('coarser options say they cannot be undone, before the tap',
      (tester) async {
    await pump(tester, LocationPrecision.balanced);
    const warning = 'Re-rounds your 2 saved places now. Choosing a finer '
        'setting later won’t bring back the detail.';
    final coarseTile = find.ancestor(
        of: find.textContaining('Coarse'),
        matching: find.byType(RadioListTile<LocationPrecision>));
    expect(
        find.descendant(of: coarseTile, matching: find.textContaining(warning)),
        findsOneWidget);
    // The current and finer options carry no warning.
    expect(find.textContaining(warning), findsOneWidget);
  });

  testWidgets('the geocoder request is on the screen too', (tester) async {
    await pump(tester, LocationPrecision.balanced);
    expect(find.text(OpenMeteo.geocodeUrl('Berlin').toString()),
        findsOneWidget);
    expect(find.textContaining('goes exactly as you type it'), findsOneWidget);
  });

  testWidgets('the request URLs use the ladder code face', (tester) async {
    // 'monospace' is a platform family. On the web CanvasKit has none, and
    // with the CDN Roboto gone (C13) the URL boxes rendered empty in
    // Chromium. OhTypography.code() is Nunito on the web (ohStyle 0.9.1).
    await pump(tester, LocationPrecision.balanced);
    final urls = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .where((t) => t.data!.startsWith('https://'))
        .toList();
    expect(urls, hasLength(2));
    // code() is inherit: false since ohStyle 0.9.2 (a themed merge used to
    // prefix 'monospace' into a family nobody has), so it takes no colour
    // from the theme: the screen must hand it one.
    final onSurface = Theme.of(tester.element(find.byType(SelectableText).first))
        .colorScheme
        .onSurface;
    for (final t in urls) {
      expect(t.style,
          OhTypography.code(color: onSurface).copyWith(fontSize: 11.5),
          reason: t.data);
    }
    for (final e in tester.widgetList<EditableText>(find.byType(EditableText))
        .where((e) => e.controller.text.startsWith('https://'))) {
      expect(e.style.fontFamily, 'monospace', reason: 'drawn family');
      expect(e.style.color, onSurface, reason: 'drawn colour');
    }
    expect(OhTypography.code(web: true).fontFamily,
        'packages/openhearth_design/Nunito');
  });

  testWidgets('no overflow at 320 dp x 3.0', (tester) async {
    await pump(tester, LocationPrecision.balanced,
        scale: 3, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
