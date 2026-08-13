import 'package:flutter/material.dart';
import 'package:budget_book/core/theme/bb_colors.dart';

class AppTheme {
  AppTheme._();

  static const _fontFamily = 'NotoSansKR';

  /// Brand teal on light surfaces (also the [ColorScheme] seed).
  static const Color _brandLight = BbColors.brandSeed;

  /// Brand teal lifted for dark surfaces.
  static const Color _brandDark = BbColors.brandDark;

  /// Foreground on [_brandDark].
  static const Color _onBrandDark = Color(0xFF003731);

  /// Foreground on [_brandLight].
  static const Color _onBrandLight = Color(0xFFFFFFFF);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _brandLight,
    brightness: Brightness.light,
  ).copyWith(primary: _brandLight, onPrimary: _onBrandLight);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _brandLight,
    brightness: Brightness.dark,
  ).copyWith(primary: _brandDark, onPrimary: _onBrandDark);

  static ThemeData get light => _base(_lightScheme, BbColors.light);

  static ThemeData get dark => _base(_darkScheme, BbColors.dark);

  static ThemeData _base(ColorScheme scheme, BbColors bbColors) => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: scheme,
        extensions: <ThemeExtension<dynamic>>[bbColors],
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}
