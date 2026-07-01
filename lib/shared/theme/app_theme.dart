import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // The Material-scale Lora/Nunito ladder now comes from openhearth_design's
  // OhTypography.materialTextTheme — byte-identical to the const block this
  // app hand-rolled before (pinned by material_text_theme_identity_test.dart
  // and the goldens). Fonts stay BUNDLED (assets/fonts/, declared in pubspec)
  // and are referenced by family — not fetched from fonts.gstatic.com at
  // runtime. This keeps the app fully local-first: no font egress on first
  // launch. See also app_text_styles.dart.
  static const TextTheme _textTheme = OhTypography.materialTextTheme;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sky500,
      brightness: Brightness.light,
      surface: AppColors.mist50,
      onSurface: AppColors.mist900,
    ),
    scaffoldBackgroundColor: AppColors.mist50,
    shadowColor: AppColors.mist900.withValues(alpha: 0.15),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.mist100,
      shadowColor: AppColors.mist900.withValues(alpha: 0.1),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sky500,
      brightness: Brightness.dark,
      surface: AppColors.night,
    ),
    scaffoldBackgroundColor: AppColors.night,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.night2,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
