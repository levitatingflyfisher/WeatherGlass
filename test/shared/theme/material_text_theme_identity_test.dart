import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// Tier-T law: adopting `OhTypography.materialTextTheme` must be a ZERO
/// visual change. This test pins byte-identity between the package ladder and
/// what WeatherGlass's themes actually resolve — every role's family, size,
/// and weight. It passed against the hand-rolled const block BEFORE the swap
/// (proving the package const is byte-identical) and must keep passing after.
void main() {
  const roles = <String, TextStyle? Function(TextTheme)>{
    'displayLarge': _dl, 'displayMedium': _dm, 'displaySmall': _ds,
    'headlineLarge': _hl, 'headlineMedium': _hm, 'headlineSmall': _hs,
    'titleLarge': _tl, 'titleMedium': _tm, 'titleSmall': _ts,
    'bodyLarge': _bl, 'bodyMedium': _bm, 'bodySmall': _bs,
    'labelLarge': _ll, 'labelMedium': _lm, 'labelSmall': _ls,
  };

  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    test('${entry.key} theme text roles are byte-identical to '
        'OhTypography.materialTextTheme', () {
      final resolved = entry.value.textTheme;
      for (final role in roles.entries) {
        final expected = role.value(OhTypography.materialTextTheme)!;
        final actual = role.value(resolved)!;
        expect(actual.fontFamily, expected.fontFamily,
            reason: '${role.key} fontFamily');
        expect(actual.fontSize, expected.fontSize,
            reason: '${role.key} fontSize');
        expect(actual.fontWeight, expected.fontWeight,
            reason: '${role.key} fontWeight');
        expect(expected.letterSpacing, isNull,
            reason: '${role.key} ladder must not set letterSpacing');
        expect(expected.height, isNull,
            reason: '${role.key} ladder must not set height');
      }
    });
  }
}

TextStyle? _dl(TextTheme t) => t.displayLarge;
TextStyle? _dm(TextTheme t) => t.displayMedium;
TextStyle? _ds(TextTheme t) => t.displaySmall;
TextStyle? _hl(TextTheme t) => t.headlineLarge;
TextStyle? _hm(TextTheme t) => t.headlineMedium;
TextStyle? _hs(TextTheme t) => t.headlineSmall;
TextStyle? _tl(TextTheme t) => t.titleLarge;
TextStyle? _tm(TextTheme t) => t.titleMedium;
TextStyle? _ts(TextTheme t) => t.titleSmall;
TextStyle? _bl(TextTheme t) => t.bodyLarge;
TextStyle? _bm(TextTheme t) => t.bodyMedium;
TextStyle? _bs(TextTheme t) => t.bodySmall;
TextStyle? _ll(TextTheme t) => t.labelLarge;
TextStyle? _lm(TextTheme t) => t.labelMedium;
TextStyle? _ls(TextTheme t) => t.labelSmall;
