// lib/features/weather/domain/units.dart

/// Display unit system. Glass always *requests* metric from the provider (a
/// fixed request shape — the user's unit preference never changes the URL, so
/// it can't add a fingerprint) and converts for display here.
enum UnitSystem {
  metric('Metric', '°C', 'km/h', 'mm'),
  imperial('Imperial', '°F', 'mph', 'in');

  const UnitSystem(this.label, this.tempSuffix, this.windSuffix, this.precipSuffix);
  final String label;
  final String tempSuffix;
  final String windSuffix;
  final String precipSuffix;

  static UnitSystem fromName(String? name) => UnitSystem.values.firstWhere(
        (u) => u.name == name,
        orElse: () => UnitSystem.metric,
      );
}

double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;
double kmhToMph(double kmh) => kmh * 0.621371;
double mmToInches(double mm) => mm / 25.4;

/// Temperature for display, rounded to a whole degree with the ° glyph.
String formatTemp(double celsius, UnitSystem u) {
  final v = u == UnitSystem.imperial ? celsiusToFahrenheit(celsius) : celsius;
  return '${v.round()}°';
}

/// Temperature with the unit suffix (e.g. "21°C") — used where the unit isn't
/// otherwise obvious.
String formatTempWithUnit(double celsius, UnitSystem u) =>
    '${formatTemp(celsius, u)}${u == UnitSystem.imperial ? 'F' : 'C'}';

String formatWind(double kmh, UnitSystem u) {
  final v = u == UnitSystem.imperial ? kmhToMph(kmh) : kmh;
  return '${v.round()} ${u.windSuffix}';
}

String formatPrecip(double mm, UnitSystem u) {
  if (u == UnitSystem.imperial) {
    return '${mmToInches(mm).toStringAsFixed(2)} ${u.precipSuffix}';
  }
  // Metric: one decimal for sub-cm amounts reads better than an int.
  return '${mm.toStringAsFixed(mm < 10 ? 1 : 0)} ${u.precipSuffix}';
}
