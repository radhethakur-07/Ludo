import 'package:flutter/material.dart';

/// Design system and theme tokens for Duo Ludo.
class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color surfaceCard = Color(0xFF24334C);
  static const Color surfaceElevated = Color(0xFF2C3E50);

  static const Color redPrimary = Color(0xFFEF4444);   // Bright Vibrant Red
  static const Color redSecondary = Color(0xFFB91C1C); // Darker Red
  static const Color redLight = Color(0xFFFCA5A5);

  static const Color greenPrimary = Color(0xFF10B981); // Bright Jade Green
  static const Color greenSecondary = Color(0xFF047857); // Darker Green
  static const Color greenLight = Color(0xFF6EE7B7);

  static const Color gold = Color(0xFFF59E0B);        // Golden Yellow
  static const Color blueAccent = Color(0xFF38BDF8);   // Cyan / Sky Accent
  static const Color safeStar = Color(0xFFFFD700);     // Golden star

  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: blueAccent,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: textLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
