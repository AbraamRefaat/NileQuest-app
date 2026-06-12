import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF1F4E5F); // Deep teal
  static const primaryLight = Color(0xFF2A6678); // Lighter teal (header gradients)
  static const secondary = Color(0xFFD4AF7A); // Sandy gold
  static const accent = Color(0xFFE67E22); // Warm orange
  static const cream = Color(0xFFF5F1E8); // Warm off-white
  static const charcoal = Color(0xFF2C3E50); // Dark gray-blue
  static const success = Color(0xFF27AE60); // Green (confirmations, completed)
  static const textSecondary = Color(0x992C3E50); // charcoal at 60%
  static const textMuted = Color(0x662C3E50); // charcoal at 40%

  static const headerGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Spacing scale — use instead of magic padding numbers.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radius scale.
class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// Shared text styles for the recurring inline styles across screens.
class AppTextStyles {
  static TextStyle get screenTitle => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      );

  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.charcoal,
        letterSpacing: 0.2,
      );

  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.charcoal,
      );

  static TextStyle get cardSubtitle => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        color: AppColors.textSecondary,
      );

  static TextStyle get chipLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      
      // Text Theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.charcoal,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.charcoal,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.charcoal,
        ),
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
