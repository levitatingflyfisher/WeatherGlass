import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';

void main() {
  // This is the product. The whole privacy claim — "no unique request
  // fingerprint" — lives or dies on the forecast URL carrying ONLY a fixed
  // parameter set plus the (already-rounded) coordinates: no API key, no
  // per-user/per-install token, no cache-busting timestamp, nothing that could
  // link a request to one user. If anyone ever adds such a parameter, this test
  // must fail.
  group('forecastUrl is fingerprint-free', () {
    final url = OpenMeteo.forecastUrl(52.52, 13.41);

    test('hits the keyless Open-Meteo forecast endpoint', () {
      expect(url.scheme, 'https');
      expect(url.host, 'api.open-meteo.com');
      expect(url.path, '/v1/forecast');
    });

    test('carries EXACTLY the fixed params + coords, nothing else', () {
      expect(
        url.queryParameters.keys.toSet(),
        {
          'latitude',
          'longitude',
          'current',
          'hourly',
          'daily',
          'timezone',
          'forecast_days',
        },
        reason: 'an extra query parameter is a potential fingerprint',
      );
    });

    test('sends the given (rounded) coordinates and only those vary', () {
      expect(url.queryParameters['latitude'], '52.52');
      expect(url.queryParameters['longitude'], '13.41');
      final other = OpenMeteo.forecastUrl(40.71, -74.01);
      // Everything except the coordinates is byte-identical between locations.
      final fixedOf = (Uri u) => Map.of(u.queryParameters)
        ..remove('latitude')
        ..remove('longitude');
      expect(fixedOf(other), fixedOf(url));
    });

    test('contains no key / token / cache-buster of any known shape', () {
      const banned = {
        'apikey', 'api_key', 'key', 'appid', 'token', 'access_token',
        'uid', 'user', 'user_id', 'client_id', 'install_id', 'device_id',
        'session', 'sid', 'nonce', 'cb', '_', 't', 'ts', 'timestamp', 'rand',
      };
      for (final k in url.queryParameters.keys) {
        expect(banned.contains(k.toLowerCase()), isFalse,
            reason: 'parameter "$k" looks like a tracking identifier');
      }
      // And there is no userinfo / fragment carrying identity either.
      expect(url.userInfo, isEmpty);
      expect(url.fragment, isEmpty);
    });
  });

  group('geocodeUrl', () {
    test('is the keyless geocoding endpoint with only search params', () {
      final url = OpenMeteo.geocodeUrl('Berlin');
      expect(url.host, 'geocoding-api.open-meteo.com');
      expect(url.path, '/v1/search');
      expect(url.queryParameters.keys.toSet(),
          {'name', 'count', 'language', 'format'});
      expect(url.queryParameters['name'], 'Berlin');
    });
  });
}
