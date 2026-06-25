// lib/features/weather/data/models.dart
import 'package:glass/features/weather/domain/weather_code.dart';

/// A place from the geocoding search (also the shape we store as a saved
/// location). Coordinates here are the *raw* geocoder result; they are rounded
/// at the boundary before being persisted or queried.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
    this.countryCode,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? admin1; // state/region
  final String? country;
  final String? countryCode;

  /// "State of Berlin, Germany" — the secondary line under the place name.
  String get region => [admin1, country].whereType<String>().join(', ');

  factory GeoPlace.fromGeocoding(Map<String, dynamic> j) => GeoPlace(
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        admin1: j['admin1'] as String?,
        country: j['country'] as String?,
        countryCode: j['country_code'] as String?,
      );
}

/// Current conditions slice of a forecast.
class CurrentConditions {
  const CurrentConditions({
    required this.time,
    required this.temperatureC,
    required this.apparentC,
    required this.weatherCode,
    required this.isDay,
    required this.windKmh,
    required this.humidity,
    required this.precipMm,
  });

  final DateTime time; // location-local wall clock
  final double temperatureC;
  final double apparentC;
  final int weatherCode;
  final bool isDay;
  final double windKmh;
  final int humidity;
  final double precipMm;

  WeatherCondition get condition => conditionFromWmo(weatherCode);
}

/// One hour of the hourly forecast.
class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperatureC,
    required this.precipProbability,
    required this.weatherCode,
  });
  final DateTime time;
  final double temperatureC;
  final int precipProbability;
  final int weatherCode;
  WeatherCondition get condition => conditionFromWmo(weatherCode);
}

/// One day of the daily forecast.
class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.weatherCode,
    required this.highC,
    required this.lowC,
    required this.precipProbabilityMax,
    this.sunrise,
    this.sunset,
  });
  final DateTime date;
  final int weatherCode;
  final double highC;
  final double lowC;
  final int precipProbabilityMax;
  final DateTime? sunrise;
  final DateTime? sunset;
  WeatherCondition get condition => conditionFromWmo(weatherCode);
}

/// A full forecast for one location.
class Forecast {
  const Forecast({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.utcOffsetSeconds,
  });

  final CurrentConditions current;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;
  final int utcOffsetSeconds;

  /// Parse Open-Meteo's `/v1/forecast` response (parallel arrays). Times are
  /// the location's local wall clock (we requested `timezone=auto`), so they
  /// are parsed naively and shown as-is — never timezone-shifted.
  factory Forecast.fromJson(Map<String, dynamic> j) {
    DateTime? parse(String? s) => (s == null) ? null : DateTime.parse(s);

    final c = j['current'] as Map<String, dynamic>;
    final current = CurrentConditions(
      time: DateTime.parse(c['time'] as String),
      temperatureC: (c['temperature_2m'] as num).toDouble(),
      apparentC: (c['apparent_temperature'] as num).toDouble(),
      weatherCode: (c['weather_code'] as num).toInt(),
      isDay: (c['is_day'] as num).toInt() == 1,
      windKmh: (c['wind_speed_10m'] as num).toDouble(),
      humidity: (c['relative_humidity_2m'] as num).toInt(),
      precipMm: (c['precipitation'] as num?)?.toDouble() ?? 0,
    );

    final h = j['hourly'] as Map<String, dynamic>;
    final ht = (h['time'] as List).cast<String>();
    final htemp = (h['temperature_2m'] as List);
    final hpp = (h['precipitation_probability'] as List);
    final hcode = (h['weather_code'] as List);
    final hourly = [
      for (var i = 0; i < ht.length; i++)
        HourlyPoint(
          time: DateTime.parse(ht[i]),
          temperatureC: (htemp[i] as num).toDouble(),
          precipProbability: (hpp[i] as num?)?.toInt() ?? 0,
          weatherCode: (hcode[i] as num).toInt(),
        ),
    ];

    final d = j['daily'] as Map<String, dynamic>;
    final dt = (d['time'] as List).cast<String>();
    final dcode = (d['weather_code'] as List);
    final dmax = (d['temperature_2m_max'] as List);
    final dmin = (d['temperature_2m_min'] as List);
    final dpp = (d['precipitation_probability_max'] as List);
    final dsr = (d['sunrise'] as List?)?.cast<String?>();
    final dss = (d['sunset'] as List?)?.cast<String?>();
    final daily = [
      for (var i = 0; i < dt.length; i++)
        DailyPoint(
          date: DateTime.parse(dt[i]),
          weatherCode: (dcode[i] as num).toInt(),
          highC: (dmax[i] as num).toDouble(),
          lowC: (dmin[i] as num).toDouble(),
          precipProbabilityMax: (dpp[i] as num?)?.toInt() ?? 0,
          sunrise: parse(dsr?[i]),
          sunset: parse(dss?[i]),
        ),
    ];

    return Forecast(
      current: current,
      hourly: hourly,
      daily: daily,
      utcOffsetSeconds: (j['utc_offset_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
