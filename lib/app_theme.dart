import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ================================================================
// RENK PALETİ
// ================================================================
class AppColors {
  static const inkPlum = Color(0xFF2B1B33); // koyu metin / arka plan
  static const roseEmber = Color(0xFFE8637A); // ana vurgu rengi
  static const softPeach = Color(0xFFF7DCC6); // ikincil sıcak ton
  static const creamPaper = Color(0xFFFBF3EA); // ana zemin
  static const mossSage = Color(0xFF7C9885); // pozitif/bağlı durumlar
  static const mutedCharcoal = Color(0xFF3A3540); // gövde metni
  static const cardWhite = Color(0xFFFFFFFF);
  static const warningAmber = Color(0xFFD98E4A);
  static const dangerRose = Color(0xFFD1495B);
}

// ================================================================
// TEMA
// ================================================================
class AppTheme {
  static ThemeData get theme {
    final baseTextTheme = TextTheme(
      // Başlıklar — karakterli serif
      displayLarge: GoogleFonts.fraunces(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: AppColors.inkPlum,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.inkPlum,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.inkPlum,
      ),
      // Gövde — temiz sans-serif
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        color: AppColors.mutedCharcoal,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        color: AppColors.mutedCharcoal,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        color: AppColors.mutedCharcoal.withValues(alpha: 0.7),
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.creamPaper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.roseEmber,
        primary: AppColors.roseEmber,
        secondary: AppColors.mossSage,
        surface: AppColors.cardWhite,
        error: AppColors.dangerRose,
      ),
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.creamPaper,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.inkPlum,
        ),
        iconTheme: const IconThemeData(color: AppColors.inkPlum),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.roseEmber,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.roseEmber, width: 2),
        ),
      ),
    );
  }
}