import 'package:flutter_test/flutter_test.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

void main() {
  group('conditionFromWmo', () {
    test('maps the canonical WMO codes', () {
      expect(conditionFromWmo(0), WeatherCondition.clear);
      expect(conditionFromWmo(2), WeatherCondition.partlyCloudy);
      expect(conditionFromWmo(3), WeatherCondition.overcast);
      expect(conditionFromWmo(45), WeatherCondition.fog);
      expect(conditionFromWmo(61), WeatherCondition.rain);
      expect(conditionFromWmo(71), WeatherCondition.snow);
      expect(conditionFromWmo(80), WeatherCondition.showers);
      expect(conditionFromWmo(95), WeatherCondition.thunderstorm);
      expect(conditionFromWmo(96), WeatherCondition.thunderstormHail);
    });

    test('unknown codes fall back to overcast (no throw)', () {
      expect(conditionFromWmo(999), WeatherCondition.overcast);
      expect(conditionFromWmo(-1), WeatherCondition.overcast);
    });
  });

  group('icon + precipitation flags', () {
    test('clear swaps sun/moon by day; rain is the same glyph', () {
      expect(iconFor(WeatherCondition.clear, true),
          isNot(iconFor(WeatherCondition.clear, false)));
      expect(iconFor(WeatherCondition.rain, true),
          iconFor(WeatherCondition.rain, false));
    });

    test('isPrecipitating is true only for wet/white conditions', () {
      expect(WeatherCondition.clear.isPrecipitating, isFalse);
      expect(WeatherCondition.overcast.isPrecipitating, isFalse);
      expect(WeatherCondition.rain.isPrecipitating, isTrue);
      expect(WeatherCondition.snow.isPrecipitating, isTrue);
      expect(WeatherCondition.thunderstorm.isPrecipitating, isTrue);
    });
  });
}
