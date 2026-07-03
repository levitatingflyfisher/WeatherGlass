// lib/features/weather/data/weather_repository.dart
import 'dart:convert';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/domain/geo.dart';

/// Fetches forecasts through Open-Meteo and caches the raw JSON per location.
/// A fresh cache (under [ttl]) is served without touching the network — instant,
/// offline-friendly, and privacy-minded (fewer requests to correlate).
class WeatherRepository {
  WeatherRepository(this._db, this._client);
  final AppDatabase _db;
  final OpenMeteo _client;

  static const ttl = Duration(minutes: 30);

  Future<CachedForecast?> _cached(String locationId) =>
      (_db.select(_db.forecastCache)
            ..where((t) => t.locationId.equals(locationId)))
          .getSingleOrNull();

  /// The freshest forecast for [loc]: a cached copy if it is under [ttl] (unless
  /// [force]), otherwise a fresh fetch that is then cached.
  Future<Forecast> getForecast(
    SavedLocation loc, {
    required LocationPrecision precision,
    bool force = false,
    int? nowMillis,
  }) async {
    // Re-round at the SEND boundary with the CURRENT precision. Rows are rounded
    // at add-time, but if the user later picks a COARSER precision the saved rows
    // keep their finer grid — and every request would then leak it. Rounding here
    // makes the privacy setting authoritative for every outbound request,
    // regardless of when (or at what precision) the location was saved.
    final (lat, lon) = roundForPrecision(loc.lat, loc.lon, precision);
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      final row = await _cached(loc.id);
      if (row != null && now - row.fetchedAt < ttl.inMilliseconds) {
        return Forecast.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
      }
    }
    final body = await _client.fetchForecastJson(lat, lon);
    await _db.into(_db.forecastCache).insertOnConflictUpdate(
          ForecastCacheCompanion.insert(
            locationId: loc.id,
            payload: body,
            fetchedAt: now,
          ),
        );
    return Forecast.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// When the cache was last written for [locationId] (epoch ms), or null.
  Future<int?> cachedAt(String locationId) async =>
      (await _cached(locationId))?.fetchedAt;
}
