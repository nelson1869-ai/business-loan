import 'package:flutter/material.dart';

/// Premium modern design system for Lending Nelson Borrower Mobile App.
class BorrowerAppTheme {
  static const Color primaryColor = Color(0xFF0F172A); // Slate 900
  static const Color accentColor = Color(0xFF2563EB); // Royal Blue 600
  static const Color accentGradientEnd = Color(0xFF1D4ED8); // Royal Blue 700
  static const Color backgroundColor =
      Color(0xFFF1F5F9); // Soft Pearl/Slate 100
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF0F172A); // Slate 900
  static const Color mutedColor = Color(0xFF64748B); // Slate 500
  static const Color inputFillColor = Color(0xFFF8FAFC); // Slate 50
  static const Color borderColor = Color(0xFFE2E8F0); // Slate 200
  static const Color errorColor = Color(0xFFEF4444); // Red 500

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
