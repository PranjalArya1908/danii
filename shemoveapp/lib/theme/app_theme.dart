import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';

class SafeLoopTheme {
  static ThemeData darkTheme() {
    final colorScheme = const ColorScheme.dark(
      primary: SafeLoopColors.primaryViolet,
      onPrimary: SafeLoopColors.textPrimary,
      primaryContainer: SafeLoopColors.deepViolet,
      onPrimaryContainer: SafeLoopColors.electricLavender,
      secondary: SafeLoopColors.vibrantLavender,
      onSecondary: SafeLoopColors.midnightDarkBackground,
      secondaryContainer: SafeLoopColors.midnightDarkSurfaceVariant,
      onSecondaryContainer: SafeLoopColors.electricLavender,
      tertiary: SafeLoopColors.infoBlue,
      onTertiary: SafeLoopColors.midnightDarkBackground,
      surface: SafeLoopColors.midnightDarkSurface,
      onSurface: SafeLoopColors.textPrimary,
      surfaceContainerHighest: SafeLoopColors.midnightDarkSurfaceVariant,
      onSurfaceVariant: SafeLoopColors.textSecondary,
      outline: SafeLoopColors.midnightDarkCardBorder,
      error: SafeLoopColors.emergencyRed,
      onError: SafeLoopColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SafeLoopColors.midnightDarkBackground,
      cardColor: SafeLoopColors.midnightDarkCard,
      dividerColor: SafeLoopColors.midnightDarkCardBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: SafeLoopColors.midnightDarkBackground,
        foregroundColor: SafeLoopColors.textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: SafeLoopColors.midnightDarkSurface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SafeLoopColors.primaryViolet,
          foregroundColor: Colors.white,
          shape: roundedBorder(16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: SafeLoopColors.midnightDarkCardBorder),
          shape: roundedBorder(16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SafeLoopColors.midnightDarkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SafeLoopColors.midnightDarkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SafeLoopColors.midnightDarkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SafeLoopColors.primaryViolet, width: 1.5),
        ),
        labelStyle: const TextStyle(color: SafeLoopColors.textSecondary),
      ),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = const ColorScheme.light(
      primary: Color(0xFF7C3AED),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE9FE),
      onPrimaryContainer: Color(0xFF5B21B6),
      secondary: Color(0xFF6366F1),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0E7FF),
      onSecondaryContainer: Color(0xFF3730A3),
      tertiary: Color(0xFF0284C7),
      onTertiary: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFFF1F5F9),
      onSurfaceVariant: Color(0xFF475569),
      outline: Color(0xFFE2E8F0),
      error: Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          shape: roundedBorder(16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: roundedBorder(16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF475569)),
      ),
    );
  }
}

RoundedRectangleBorder roundedBorder(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

class AppTheme {
  static ThemeData get darkTheme => SafeLoopTheme.darkTheme();
  static ThemeData get lightTheme => SafeLoopTheme.lightTheme();
}
