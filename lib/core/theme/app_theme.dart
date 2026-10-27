import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF342A25);
  static const _clay = Color(0xFF9C5F47);
  static const _cream = Color(0xFFFAF7F2);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _clay,
      brightness: Brightness.light,
      surface: _cream,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}
