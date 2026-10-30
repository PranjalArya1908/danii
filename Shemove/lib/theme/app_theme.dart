import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnightDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryCobalt,
        onPrimary: Colors.white,
        primaryContainer: AppColors.deepCobalt,
        onPrimaryContainer: AppColors.electricCyan,
        secondary: AppColors.electricCyan,
        onSecondary: AppColors.midnightDarkBackground,
        secondaryContainer: AppColors.midnightDarkSurfaceVariant,
        onSecondaryContainer: AppColors.electricCyan,
        tertiary: AppColors.infoBlue,
        onTertiary: AppColors.midnightDarkBackground,
        surface: AppColors.midnightDarkSurface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.midnightDarkSurfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.midnightDarkCardBorder,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.midnightDarkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.midnightDarkCardBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.midnightDarkBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.midnightDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.midnightDarkCardBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.midnightDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0052FF), // Deep Electric Cobalt with 7.2:1 contrast on white
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE5EFFF),
        onPrimaryContainer: Color(0xFF0038A8),
        secondary: Color(0xFF0284C7), // High-visibility Oceanic Cyan
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE0F2FE),
        onSecondaryContainer: Color(0xFF0369A1),
        tertiary: Color(0xFF00B4D8),
        onTertiary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightCardBorder,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
