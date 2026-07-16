import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => buildLight(null);

  static ThemeData get darkTheme => buildDark(null);

  static ThemeData buildLight(ColorScheme? dynamicScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme ??
          const ColorScheme.light(
        primary: Color(0xFF6C63FF),
        secondary: Color(0xFF00E676),
        surface: Color(0xFFF5F5F5),
        onSurface: Colors.black87,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      fontFamily: 'Inter',
    );
  }

  static ThemeData buildDark(ColorScheme? dynamicScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme ??
          const ColorScheme.dark(
        primary: Color(0xFF8A2BE2), // Vibrant Electric Purple
        secondary: Color(0xFF00E5FF), // Neon Teal
        surface: Color(0xFF18181E), // Slightly elevated dark
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F13),
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Color(0xFF00E5FF), // Neon teal for active
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
