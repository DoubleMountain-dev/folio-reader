// lib/utils/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color inkDark     = Color(0xFF1A1208);
  static const Color paperWarm   = Color(0xFFF5F0E8);
  static const Color creamLight  = Color(0xFFEDE8DA);
  static const Color accentRed   = Color(0xFFC0392B);
  static const Color goldAccent  = Color(0xFFB8860B);
  static const Color mutedBrown  = Color(0xFF7A6E5A);
  static const Color woodBrown   = Color(0xFF2C1810);
  static const Color spineNavy   = Color(0xFF2D3561);
  static const Color spineForest = Color(0xFF1B4332);
  static const Color spineCrimson= Color(0xFF6B2D3E);
  static const Color spineAmber  = Color(0xFF7B3F00);
  static const Color spinePlum   = Color(0xFF4A1942);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.accentRed,
        secondary: AppColors.goldAccent,
        surface: AppColors.paperWarm,
        onSurface: AppColors.inkDark,
      ),
      scaffoldBackgroundColor: AppColors.creamLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.woodBrown,
        foregroundColor: AppColors.paperWarm,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.paperWarm,
        ),
        elevation: 0,
      ),
    );
  }
}
