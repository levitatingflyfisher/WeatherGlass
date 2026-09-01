import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persona F4 and audit dont-make-me-think-05/08: the search control was a
/// return-key glyph and an empty result rendered nothing.
void main() {
  Future<List<Uri>> pump(WidgetTester tester, String body) async {
    final asked = <Uri>[];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        openMeteoProvider.overrideWithValue(OpenMeteo(
            client: MockClient((r) async {
          asked.add(r.url);
          return http.Response(body, 200);
        }))),
      ],
      child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SafeArea(child: AddLocationSheet()))),
    ));
    await tester.pump();
    return asked;
  }

  testWidgets('a visible Search button runs the search', (tester) async {
    final asked = await pump(tester, '{"results": []}');
    await tester.enterText(find.byType(TextField), 'Porto');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(asked.single.queryParameters['name'], 'Porto');
  });

  testWidgets('an empty result says so, naming the query', (tester) async {
    await pump(tester, '{}');
    await tester.enterText(find.byType(TextField), 'Prot');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No places found for “Prot”'), findsOneWidget);
  });

  testWidgets('a new search clears the old empty message', (tester) async {
    await pump(tester, '{}');
    await tester.enterText(find.byType(TextField), 'Prot');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Porto');
    await tester.pump();
    expect(find.textContaining('No places found'), findsNothing);
  });
}
