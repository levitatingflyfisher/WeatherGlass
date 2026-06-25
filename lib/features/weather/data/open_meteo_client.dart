// lib/features/weather/data/open_meteo_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:glass/features/weather/data/models.dart';

/// A thin client over Open-Meteo — the one source Glass uses: no API key,
/// wildcard CORS (callable from a pure browser PWA), no cookies, CC-BY 4.0 data.
///
/// The whole privacy posture rests on [forecastUrl] sending a FIXED set of
/// parameters with only the (already-rounded) coordinates varying. There is no
/// API key, no per-install/per-user token, no cache-busting timestamp, and no
/// custom header — so a request carries no identifier that could link it to one
/// user. That property is pinned by a test; treat any new query parameter here
/// as a privacy change, not a feature.
class OpenMeteo {
  OpenMeteo({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const forecastHost = 'api.open-meteo.com';
  static const geocodeHost = 'geocoding-api.open-meteo.com';

  /// The fixed forecast query. Metric is always requested (the user's display
  /// unit is converted client-side) so the unit preference never alters the URL.
  static const Map<String, String> _forecastParams = {
    'current':
        'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
    'hourly': 'temperature_2m,precipitation_probability,weather_code',
    'daily':
        'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset',
    'timezone': 'auto',
    'forecast_days': '7',
  };

  /// Build the forecast request URL for a coordinate. The coordinate must
  /// already be rounded to the user's precision — this method does not round,
  /// it only assembles the fixed request.
  static Uri forecastUrl(double lat, double lon) => Uri.https(
        forecastHost,
        '/v1/forecast',
        {
          'latitude': _coord(lat),
          'longitude': _coord(lon),
          ..._forecastParams,
        },
      );

  /// Geocoding search URL. Note: the search *query text* is inherently sent to
  /// the provider — that is the nature of a name lookup and is separate from the
  /// per-location forecast fingerprint. No key, wildcard CORS.
  static Uri geocodeUrl(String name) => Uri.https(
        geocodeHost,
        '/v1/search',
        {
          'name': name,
          'count': '8',
          'language': 'en',
          'format': 'json',
        },
      );

  static String _coord(double v) => v.toString();

  /// Fetch the raw forecast body (so callers can cache the JSON verbatim). No
  /// custom headers: the browser controls them anyway and Open-Meteo requires
  /// none, which keeps the request indistinguishable from any other client's.
  Future<String> fetchForecastJson(double lat, double lon) async {
    final res = await _client.get(forecastUrl(lat, lon));
    if (res.statusCode != 200) {
      throw WeatherException('Forecast request failed (${res.statusCode}).');
    }
    return res.body;
  }

  Future<Forecast> fetchForecast(double lat, double lon) async => Forecast.fromJson(
      jsonDecode(await fetchForecastJson(lat, lon)) as Map<String, dynamic>);

  Future<List<GeoPlace>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final res = await _client.get(geocodeUrl(q));
    if (res.statusCode != 200) {
      throw WeatherException('Place search failed (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    return [
      for (final r in results)
        GeoPlace.fromGeocoding(r as Map<String, dynamic>),
    ];
  }

  void close() => _client.close();
}

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}
