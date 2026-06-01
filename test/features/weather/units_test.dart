import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/domain/units.dart';

void main() {
  test('celsius/fahrenheit conversion', () {
    expect(celsiusToFahrenheit(0), 32);
    expect(celsiusToFahrenheit(100), 212);
    expect(celsiusToFahrenheit(-40), -40);
  });

  test('formatTemp rounds and suffixes by unit system', () {
    expect(formatTemp(21.4, UnitSystem.metric), '21°');
    expect(formatTemp(21.6, UnitSystem.metric), '22°');
    expect(formatTemp(0, UnitSystem.imperial), '32°');
    expect(formatTempWithUnit(0, UnitSystem.imperial), '32°F');
    expect(formatTempWithUnit(20, UnitSystem.metric), '20°C');
  });

  test('formatWind converts km/h to mph for imperial', () {
    expect(formatWind(10, UnitSystem.metric), '10 km/h');
    expect(formatWind(100, UnitSystem.imperial), '62 mph');
  });

  test('UnitSystem.fromName falls back to metric', () {
    expect(UnitSystem.fromName('imperial'), UnitSystem.imperial);
    expect(UnitSystem.fromName(null), UnitSystem.metric);
    expect(UnitSystem.fromName('nope'), UnitSystem.metric);
  });
}
