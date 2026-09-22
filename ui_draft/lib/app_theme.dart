import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ground = Color(0xFFF5F1EA);
  static const canvas = Color(0xFFFDFAF4);
  static const forest = Color(0xFF1B4D3E);
  static const forestMid = Color(0xFF2D6A55);
  static const forestLight = Color(0xFFE8F0ED);
  static const amber = Color(0xFFC9631A);
  static const amberLight = Color(0xFFFDF0E6);
  static const ink = Color(0xFF1A1A18);
  static const inkMid = Color(0xFF4A4A46);
  static const inkMuted = Color(0xFF8A8A84);
  static const border = Color(0xFFDDD9D0);
  static const purple = Color(0xFF5B3A8C);
  static const purpleLight = Color(0xFFEEE8F5);
  static const teal = Color(0xFF2D6A55);
  static const tealLight = Color(0xFFE4F0EB);
  static const rust = Color(0xFFB5481A);
  static const rustLight = Color(0xFFFCEEE7);
  static const blue = Color(0xFF1A5C8C);
  static const blueLight = Color(0xFFE6F0F8);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ground,
      colorScheme: ColorScheme.light(
        primary: AppColors.forest,
        secondary: AppColors.amber,
        surface: AppColors.canvas,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.ink,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 36,
          fontWeight: FontWeight.w300,
          color: AppColors.ink,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: AppColors.ink,
          height: 1.25,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMid,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMid,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMuted,
        ),
        labelSmall: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.inkMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.canvas.withOpacity(0.95),
        selectedItemColor: AppColors.forest,
        unselectedItemColor: AppColors.inkMuted,
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.forest, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.outfit(color: AppColors.inkMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
    );
  }
}
