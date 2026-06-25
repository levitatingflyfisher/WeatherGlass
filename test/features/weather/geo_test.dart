import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/domain/geo.dart';

void main() {
  group('roundCoord', () {
    test('rounds to the requested decimals (half away from zero)', () {
      expect(roundCoord(52.524366, 2), 52.52);
      expect(roundCoord(13.41053, 2), 13.41);
      expect(roundCoord(52.526, 2), 52.53);
    });

    test('handles negative coordinates', () {
      expect(roundCoord(-33.8688, 2), -33.87);
      expect(roundCoord(-74.0061, 1), -74.0);
    });
  });

  group('roundForPrecision (the privacy lever)', () {
    const lat = 52.524366, lon = 13.410530; // exact Berlin geocode
    test('balanced keeps 2 dp (~1 km cell)', () {
      expect(roundForPrecision(lat, lon, LocationPrecision.balanced),
          (52.52, 13.41));
    });
    test('coarse keeps 1 dp (~11 km cell) — most private', () {
      expect(roundForPrecision(lat, lon, LocationPrecision.coarse),
          (52.5, 13.4));
    });
    test('precise keeps 3 dp (~110 m cell)', () {
      expect(roundForPrecision(lat, lon, LocationPrecision.precise),
          (52.524, 13.411));
    });
    test('coarser precision can never reveal more than finer', () {
      final (clat, _) = roundForPrecision(lat, lon, LocationPrecision.coarse);
      final (plat, _) = roundForPrecision(lat, lon, LocationPrecision.precise);
      // The coarse value has at most as many significant decimals as precise.
      expect(LocationPrecision.coarse.decimals,
          lessThan(LocationPrecision.precise.decimals));
      expect(clat, isNot(equals(plat)));
    });
  });

  test('LocationPrecision.fromName falls back to balanced', () {
    expect(LocationPrecision.fromName('coarse'), LocationPrecision.coarse);
    expect(LocationPrecision.fromName(null), LocationPrecision.balanced);
    expect(LocationPrecision.fromName('nonsense'), LocationPrecision.balanced);
  });
}
