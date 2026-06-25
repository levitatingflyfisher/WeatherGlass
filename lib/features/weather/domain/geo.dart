// lib/features/weather/domain/geo.dart
import 'dart:math' as math;

/// How precisely Glass stores and queries a location.
///
/// Coordinate rounding is the one privacy lever a browser app actually controls
/// (it cannot touch TLS/JA3 or the User-Agent). By rounding before anything is
/// stored or sent, the provider only ever sees a coarse grid cell — never your
/// exact home. Decimal-degree precision maps to ground distance at the equator:
/// 1 dp ≈ 11 km, 2 dp ≈ 1.1 km, 3 dp ≈ 110 m (longitude tightens toward the
/// poles, so these are upper bounds).
enum LocationPrecision {
  coarse(1, '~11 km', 'A town-scale cell. Most private; the forecast is still good.'),
  balanced(2, '~1 km', 'A neighbourhood-scale cell. The sweet spot.'),
  precise(3, '~110 m', 'A block-scale cell. Most accurate, least private.');

  const LocationPrecision(this.decimals, this.cell, this.blurb);

  /// Decimal places kept when rounding a coordinate.
  final int decimals;

  /// Human label for the grid cell size (e.g. "~1 km").
  final String cell;

  /// One-line explanation for the settings/privacy screen.
  final String blurb;

  static LocationPrecision fromName(String? name) =>
      LocationPrecision.values.firstWhere(
        (p) => p.name == name,
        orElse: () => LocationPrecision.balanced,
      );
}

/// Round one coordinate to [decimals] decimal places (half away from zero).
double roundCoord(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).roundToDouble() / factor;
}

/// Round a lat/lon pair to the grid implied by [precision]. This is applied at
/// the boundary — the moment a place is added or the device location is read —
/// so only the coarsened coordinate is ever persisted or sent to a provider.
(double lat, double lon) roundForPrecision(
  double lat,
  double lon,
  LocationPrecision precision,
) =>
    (roundCoord(lat, precision.decimals), roundCoord(lon, precision.decimals));
