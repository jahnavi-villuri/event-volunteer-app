import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the application's visual styling.
/// Enforces a consistent, premium light-only theme.
class AppColors {
  static const primary = Color(0xFF102A43);
  static const primaryDark = Color(0xFF0B1F33);
  static const accent = Color(0xFF2E7DD1);
  static const accentSoft = Color(0xFFEAF4FF);
  static const success = Color(0xFF1E7F62);
  static const danger = Color(0xFFD14B5B);
  static const background = Color(0xFFF3F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF122033);
  static const textSecondary = Color(0xFF596B7E);
  static const textMuted = Color(0xFF8295A9);
  static const border = Color(0xFFDAE5F2);
  static const borderFocus = Color(0xFF2E7DD1);
  static const lavender = Color(0xFFE9F1FF);
  static const warm = Color(0xFFF6B26B);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const card = 18.0;
  static const button = 14.0;
  static const chip = 24.0;
}

class AppTextStyles {
  static const pageHeading = TextStyle(
    color: AppColors.primaryDark,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    decoration: TextDecoration.none,
  );

  static const pageSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    height: 1.45,
    decoration: TextDecoration.none,
  );

  static const sectionHeading = TextStyle(
    color: AppColors.primary,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    decoration: TextDecoration.none,
  );

  static const itemHeading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.none,
  );
}

class AppTheme {
  static ThemeData get light {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        secondary: AppColors.accent,
        error: AppColors.danger,
      ),
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        displayMedium: baseText.displayMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        displaySmall: baseText.displaySmall?.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: baseText.bodySmall?.copyWith(color: AppColors.textSecondary),
        labelLarge: baseText.labelLarge?.copyWith(color: AppColors.textPrimary),
        labelMedium: baseText.labelMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        helperStyle: const TextStyle(color: AppColors.textSecondary),
        errorStyle: const TextStyle(color: AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: TextStyle(
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}
