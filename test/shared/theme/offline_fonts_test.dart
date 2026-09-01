import 'package:flutter_test/flutter_test.dart';
import 'package:glass/shared/theme/app_theme.dart';

/// WeatherGlass is local-first: fonts must be BUNDLED (assets/fonts/) and
/// referenced by family, never fetched from fonts.gstatic.com at runtime.
///
/// google_fonts set the family to a variant name like 'Lora_regular' and would
/// fetch the .ttf from Google on first use — a data egress on launch. Since
/// openhearth_design 0.7.1 the faces are bundled as package fonts, so the
/// family is exactly 'packages/openhearth_design/Lora' (or Nunito). Asserting
/// the exact family names guards against a regression back to runtime font
/// egress.
void main() {
  const lora = 'packages/openhearth_design/Lora';
  const nunito = 'packages/openhearth_design/Nunito';

  test('text theme uses bundled Lora/Nunito families (no runtime fetch)', () {
    final t = AppTheme.light.textTheme;
    expect(t.displayLarge!.fontFamily, lora);
    expect(t.headlineMedium!.fontFamily, lora);
    expect(t.titleLarge!.fontFamily, nunito);
    expect(t.bodyMedium!.fontFamily, nunito);
  });

  test('dark theme also uses the bundled families', () {
    final t = AppTheme.dark.textTheme;
    expect(t.displaySmall!.fontFamily, lora);
    expect(t.bodySmall!.fontFamily, nunito);
  });
}
