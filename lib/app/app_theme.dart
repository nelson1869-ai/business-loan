import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF0F172A); // Slate 900 (Deep Navy)
  static const Color accentColor = Color(
    0xFF0D9488,
  ); // Teal 600 (Primary Brand Accent)
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50 (Very light gray)
  static const Color darkBg = Color(0xFF0B0F19); // Custom Midnight Navy
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800

  // Shared Input Decoration Theme
  static InputDecorationTheme _inputTheme({required bool isDark}) {
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    const focusColor = accentColor;

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? darkSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: focusColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      labelStyle: TextStyle(color: isDark ? Colors.white60 : textMuted),
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : textMuted.withValues(alpha: 0.6),
      ),
    );
  }

  // Shared Button Theme
  static ElevatedButtonThemeData _buttonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: accentColor,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: lightBg,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: lightBg,
      inputDecorationTheme: _inputTheme(isDark: false),
      elevatedButtonTheme: _buttonTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: darkBg,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: darkBg,
      inputDecorationTheme: _inputTheme(isDark: true),
      elevatedButtonTheme: _buttonTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
