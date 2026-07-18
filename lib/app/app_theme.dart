// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Core Brand Colors
  static const Color primaryColor = Color(0xFF0F172A); // Slate 900 (Deep Navy)
  static const Color accentColor = Color(
    0xFF0D9488,
  ); // Teal 600 (Primary Brand Accent)
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Neutral Background Colors
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50 (Very light gray)
  static const Color darkBg = Color(0xFF0B0F19); // Custom Midnight Navy
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800

  // Status Colors (Success, Warning, Error, Info)
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color errorColor = Color(0xFFEF4444); // Rose 500
  static const Color infoColor = Color(0xFF3B82F6); // Blue 500

  // Shared Typography Style Definitions
  static TextTheme _textTheme({required bool isDark}) {
    final baseColor = isDark ? Colors.white : primaryColor;
    final secondaryColor = isDark ? Colors.white70 : textMuted;

    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
    );
  }

  // Custom Card Theme Styling
  static CardThemeData _cardTheme({required bool isDark}) {
    return CardThemeData(
      color: isDark ? darkSurface : Colors.white,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    );
  }

  // Shared Input Decoration Theme (TextFormField boxes)
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

  // Shared ElevatedButton Style
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
      textTheme: _textTheme(isDark: false),
      cardTheme: _cardTheme(isDark: false),
      inputDecorationTheme: _inputTheme(isDark: false),
      elevatedButtonTheme: _buttonTheme(),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: accentColor,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.black12,
        space: 24,
        thickness: 1,
      ),
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
      textTheme: _textTheme(isDark: true),
      cardTheme: _cardTheme(isDark: true),
      inputDecorationTheme: _inputTheme(isDark: true),
      elevatedButtonTheme: _buttonTheme(),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: accentColor,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white10,
        space: 24,
        thickness: 1,
      ),
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
