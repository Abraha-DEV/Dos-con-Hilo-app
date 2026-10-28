import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF37201D);
  static const _rose = Color(0xFFBE1E5D);
  static const _roseLight = Color(0xFFDF2C70);
  static const _blush = Color(0xFFFDEEF5);
  static const _cream = Color(0xFFFFFAFC);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _rose,
      brightness: Brightness.light,
      surface: _cream,
    ).copyWith(
      primary: _rose,
      onPrimary: Colors.white,
      secondary: _roseLight,
      onSecondary: _ink,
      tertiary: const Color(0xFF9D5F5B),
      surface: _cream,
      surfaceContainerHighest: _blush,
      onSurface: _ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: _ink,
            displayColor: _ink,
          ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: _cream,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _ink.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: _ink),
        floatingLabelStyle: const TextStyle(color: _rose),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _rose, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? _rose : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? _blush : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _rose),
    );
  }
}
