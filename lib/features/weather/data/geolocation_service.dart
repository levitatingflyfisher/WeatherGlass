// lib/features/weather/data/geolocation_service.dart
import 'package:geolocator/geolocator.dart';

/// A thin wrapper over geolocator for the optional "locate me" feature. Always
/// requests LOW accuracy — WeatherGlass only needs a coarse fix and then rounds it
/// further before storing. Returns null when location is unavailable or denied
/// (the caller falls back to manual search).
class GeolocationService {
  Future<({double lat, double lon})?> currentCoarse() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    return (lat: pos.latitude, lon: pos.longitude);
  }
}
