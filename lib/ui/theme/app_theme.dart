import 'package:flutter/material.dart';

/// Design system and theme tokens for Duo Ludo.
/// Vibrant, modern mobile game aesthetic with rich color gradients and high-contrast styling.
class AppTheme {
  // Vibrant Royal Gaming Palette
  static const Color background = Color(0xFF131538); // Deep Royal Indigo
  static const Color surface = Color(0xFF222452);    // Rich Purple-Indigo
  static const Color surfaceCard = Color(0xFF2B2E66); // Card surface with depth
  static const Color surfaceElevated = Color(0xFF393C7C);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1D2054),
      Color(0xFF11132F),
      Color(0xFF0C0D22),
    ],
  );

  // Player Color Accents
  static const Color redPrimary = Color(0xFFEF4444);   // Bright Vibrant Red
  static const Color redSecondary = Color(0xFFB91C1C); // Darker Red
  static const Color redLight = Color(0xFFFCA5A5);

  static const Color greenPrimary = Color(0xFF10B981); // Bright Jade Green
  static const Color greenSecondary = Color(0xFF047857); // Darker Green
  static const Color greenLight = Color(0xFF6EE7B7);

  static const Color yellowPrimary = Color(0xFFF59E0B); // Golden Sunburst
  static const Color yellowSecondary = Color(0xFFD97706);
  static const Color yellowLight = Color(0xFFFDE68A);

  static const Color bluePrimary = Color(0xFF3B82F6);  // Royal Blue
  static const Color blueSecondary = Color(0xFF1D4ED8);
  static const Color blueLight = Color(0xFF93C5FD);

  static const Color gold = Color(0xFFFFD700);        // Premium Gold
  static const Color blueAccent = Color(0xFF38BDF8);   // Cyan Accent
  static const Color safeStar = Color(0xFFFFD700);     // Golden star

  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA5B4FC);    // Soft Periwinkle

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
