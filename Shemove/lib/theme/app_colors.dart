import 'package:flutter/material.dart';

class AppColors {
  // Midnight Obsidian & Titanium Slate Design Tokens (Pure neutral depth, 0% purple tint)
  static const Color midnightDarkBackground = Color(0xFF090D16);
  static const Color midnightDarkSurface = Color(0xFF111827);
  static const Color midnightDarkSurfaceVariant = Color(0xFF1E293B);
  static const Color midnightDarkCard = Color(0xFF151F30);
  static const Color midnightDarkCardBorder = Color(0xFF2A384F);

  // High-Contrast Electric Signal Cobalt & Cyber Ice Accents (Human-Engineered Palette)
  static const Color primaryCobalt = Color(0xFF0066FF); // Luminous Electric Cobalt
  static const Color electricCyan = Color(0xFF00D4FF); // Cyber Ice Cyan (High-visibility telemetry & pulses)
  static const Color vibrantCyan = Color(0xFF38BDF8); // Signal Horizon Sky
  static const Color deepCobalt = Color(0xFF1D4ED8); // Deep Ultramarine

  // Backward-compatible aliases ensuring all screens and widgets instantly get the new theme:
  static const Color primaryViolet = primaryCobalt; // 0xFF0066FF
  static const Color electricLavender = electricCyan; // 0xFF00D4FF
  static const Color vibrantLavender = vibrantCyan; // 0xFF38BDF8
  static const Color deepViolet = deepCobalt; // 0xFF1D4ED8

  // State & Status Colors (High Contrast & Saturated)
  static const Color safeGreen = Color(0xFF00D284);
  static const Color safeGreenGlow = Color(0xFF34D399);
  static const Color safeGreenMuted = Color(0x2400D284);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberMuted = Color(0x24F59E0B);

  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color emergencyRedBright = Color(0xFFFF5252);
  static const Color emergencyRedMuted = Color(0x24EF4444);

  static const Color infoBlue = Color(0xFF00B4D8);
  static const Color infoBlueMuted = Color(0x2400B4D8);

  // Dark Text Tokens (Maximum Luminance & Sharp Contrast)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Light Mode Equivalents (Crisp Porcelain & Deep Charcoal Slate)
  static const Color lightBackground = Color(0xFFF6F8FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEDF2F7);
  static const Color lightCardBorder = Color(0xFFDCE3ED);
  static const Color lightTextPrimary = Color(0xFF0A1128);
  static const Color lightTextSecondary = Color(0xFF334155);
}
