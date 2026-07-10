import 'package:flutter/material.dart';

class AppTheme {
  static const String _fontFamily = 'Roboto';
  static const Color _primary = Color(0xFF1B7F5A);
  static const Color _primaryLight = Color(0xFF55C28B);
  static const Color _secondary = Color(0xFFB9772A);
  static const Color _accent = Color(0xFFE5F6D8);
  static const Color _error = Color(0xFFD32F2F);

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;
    TextStyle style(TextStyle? value, FontWeight weight, double height) =>
        (value ?? const TextStyle()).copyWith(
          fontFamily: _fontFamily,
          fontWeight: weight,
          height: height,
        );

    return base.copyWith(
      displayLarge: style(base.displayLarge, FontWeight.w700, 1.12),
      displayMedium: style(base.displayMedium, FontWeight.w700, 1.12),
      displaySmall: style(base.displaySmall, FontWeight.w700, 1.15),
      headlineLarge: style(base.headlineLarge, FontWeight.w700, 1.2),
      headlineMedium: style(base.headlineMedium, FontWeight.w700, 1.2),
      headlineSmall: style(base.headlineSmall, FontWeight.w700, 1.2),
      titleLarge: style(base.titleLarge, FontWeight.w700, 1.25),
      titleMedium: style(base.titleMedium, FontWeight.w600, 1.3),
      titleSmall: style(base.titleSmall, FontWeight.w600, 1.3),
      bodyLarge: style(base.bodyLarge, FontWeight.w400, 1.5),
      bodyMedium: style(base.bodyMedium, FontWeight.w400, 1.5),
      bodySmall: style(base.bodySmall, FontWeight.w400, 1.45),
      labelLarge: style(base.labelLarge, FontWeight.w600, 1.25),
      labelMedium: style(base.labelMedium, FontWeight.w600, 1.25),
      labelSmall: style(base.labelSmall, FontWeight.w600, 1.25),
    );
  }

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    textTheme: _textTheme(Brightness.light),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _secondary,
      error: _error,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7FBF4),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF173D2E),
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: _primary, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: _primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      filled: true,
      fillColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    textTheme: _textTheme(Brightness.dark),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: _primaryLight,
      secondary: _accent,
      error: _error,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D1712),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
