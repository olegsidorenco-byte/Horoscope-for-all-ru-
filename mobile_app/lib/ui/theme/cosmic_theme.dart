import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CosmicTheme {
  // Цветовая палитра
  static const Color backgroundDeep = Color(0xFF0A0D18);
  static const Color backgroundCard = Color(0xFF13182C);
  static const Color backgroundElevated = Color(0xFF1B223E);
  
  static const Color goldAccent = Color(0xFFFFD166);
  static const Color goldSoft = Color(0xFFFFE3A3);
  static const Color cyanAccent = Color(0xFF4CC9F0);
  static const Color purpleNeon = Color(0xFF9D4EDD);
  static const Color roseGlow = Color(0xFFF72585);

  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFFADB5BD);
  static const Color textMuted = Color(0xFF6C757D);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDeep,
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: cyanAccent,
        surface: backgroundCard,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
          titleLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
          titleMedium: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          bodyLarge: const TextStyle(color: textPrimary, fontSize: 15, height: 1.5),
          bodyMedium: const TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
      ),
      cardTheme: CardTheme(
        color: backgroundCard,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDeep.withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: const Color(0xFF0F111A),
          elevation: 6,
          shadowColor: goldAccent.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundCard,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: goldSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: goldAccent, width: 1.5),
        ),
      ),
    );
  }
}
