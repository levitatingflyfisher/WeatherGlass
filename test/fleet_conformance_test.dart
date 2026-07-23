import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

void main() => runFleetConformance(const FleetAppConfig(
      appId: 'weatherglass',
      styleTier: StyleTier.tokens,
      // The coordinate-rounding privacy app needs exactly these two:
      // INTERNET for the keyless Open-Meteo fetch, COARSE location so the
      // OS itself can never hand the app a precise fix. Anything more (or
      // FINE) fails here before it can ship.
      androidPermissions: {
        'android.permission.INTERNET',
        'android.permission.ACCESS_COARSE_LOCATION',
      },
      // C4 v2 — the release MERGED surface: source permissions plus
      // what plugins and the manifest merge inject. Bites when an APK
      // build has left a merged manifest under build/ (dev box).
      mergedAndroidPermissions: {
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.INTERNET',
        'com.openhearth.glass.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      },
    ));
