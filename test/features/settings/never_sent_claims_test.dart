import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Three of the six green "Never sent" ticks on the privacy screen were
/// pinned by no test (audit checklist-manifesto-01): no cookies, places and
/// history stay on this device, and the backup goes only to the share sheet.
/// A tick that cannot go red is a wish; these make each one able to.

/// Every Dart file under lib/, as (path, source).
Iterable<(String, String)> _lib() sync* {
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))) {
    yield (f.path, f.readAsStringSync());
  }
}

final _network = RegExp(r"package:http/|HttpClient|WebSocket|dart:html|"
    r"package:web/|package:dio|XMLHttpRequest|fetch\(");

void main() {
  group('No cookies', () {
    test('the one HTTP client sends no header at all, so no Cookie', () async {
      final seen = <http.BaseRequest>[];
      final client = MockClient((req) async {
        seen.add(req);
        return http.Response('{"results": []}', 200);
      });
      final api = OpenMeteo(client: client);
      await api.searchPlaces('Oslo');
      await api.fetchForecastJson(59.9, 10.7).catchError((_) => '');
      expect(seen, isNotEmpty);
      for (final r in seen) {
        expect(r.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('cookie')));
        expect(r.headers, isEmpty, reason: 'a header is a new identifier');
      }
    });

    test('no cookie store is in the app or its dependencies', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('cookie')));
      for (final (path, src) in _lib()) {
        expect(RegExp(r'CookieJar|cookie_jar|document\.cookie').hasMatch(src),
            isFalse,
            reason: path);
      }
    });
  });

  group('Your places and history stay on this device', () {
    test('only the Open-Meteo client can reach the network', () {
      final hits = [
        for (final (path, src) in _lib())
          if (_network.hasMatch(src) &&
              !path.endsWith('open_meteo_client.dart'))
            path,
      ];
      expect(hits, isEmpty);
    });

    test('and it only ever talks to Open-Meteo', () {
      final hosts = <String>{
        for (final (_, src) in _lib())
          for (final m in RegExp(r'https?://([a-z0-9.\-]+)').allMatches(src))
            m.group(1)!,
      };
      expect(hosts.difference({OpenMeteo.forecastHost, OpenMeteo.geocodeHost}),
          isEmpty);
      final client =
          File('lib/features/weather/data/open_meteo_client.dart')
              .readAsStringSync();
      final built = RegExp(r'Uri\.https?\(\s*(\w+)').allMatches(client);
      expect(built.map((m) => m.group(1)).toSet(),
          {'forecastHost', 'geocodeHost'});
    });

    test('a forecast request carries the coordinates, never a place name',
        () {
      // forecastUrl takes only numbers: a label cannot reach it.
      final url = OpenMeteo.forecastUrl(52.5, 13.4);
      expect(url.queryParameters.keys,
          isNot(anyOf(contains('name'), contains('label'))));
    });
  });

  group('An encrypted backup goes only to the share sheet', () {
    test('the backup feature has no network path', () {
      for (final (path, src) in _lib()) {
        if (!path.contains('sanctuary_backup')) continue;
        expect(_network.hasMatch(src), isFalse, reason: path);
        expect(src, isNot(contains('Uri.http')), reason: path);
      }
    });

    test('nor does the shared backup package it uses', () {
      final pkg = Directory('../packages/sanctuary_backup_ui/lib');
      expect(pkg.existsSync(), isTrue);
      for (final f in pkg
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        expect(_network.hasMatch(src) || src.contains('Uri.http'), isFalse,
            reason: f.path);
      }
    });
  });
}
