import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => buildLight(null);

  static ThemeData get darkTheme => buildDark(null);

  static ThemeData buildLight(ColorScheme? dynamicScheme) {
    final colorScheme = dynamicScheme ??
        const ColorScheme.light(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00B894),
          surface: Color(0xFFF4F6FB),
          onSurface: Color(0xFF1E1E24),
          surfaceContainerHighest: Color(0xFFEAEFF8),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF1E1E24)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1E1E24),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.70),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      fontFamily: 'Inter',
    );
  }

  static ThemeData buildDark(ColorScheme? dynamicScheme) {
    final colorScheme = dynamicScheme ??
        const ColorScheme.dark(
          primary: Color(0xFF8A2BE2), // Electric Purple
          secondary: Color(0xFF00E5FF), // Neon Teal
          surface: Color(0xFF14141E), // Elevated Dark Glass
          onSurface: Colors.white,
          surfaceContainerHighest: Color(0xFF222230),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0C0C12),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF161622).withValues(alpha: 0.90),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Color(0xFF00E5FF),
        unselectedItemColor: Colors.grey,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF8A2BE2),
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      fontFamily: 'Inter',
    );
  }
}
