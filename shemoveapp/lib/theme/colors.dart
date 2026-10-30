import 'package:flutter/material.dart';

class SafeLoopColors {
  // Midnight Dark & Electric Lavender theme tokens
  static const Color midnightDarkBackground = Color(0xFF080C1B);
  static const Color midnightDarkSurface = Color(0xFF10162F);
  static const Color midnightDarkSurfaceVariant = Color(0xFF182042);
  static const Color midnightDarkCard = Color(0xFF151C3B);
  static const Color midnightDarkCardBorder = Color(0xFF26315E);

  // Signal Cobalt & Electric Accents
  static const Color primaryCobalt = Color(0xFF0066FF);
  static const Color electricCyan = Color(0xFF00D4FF);
  static const Color vibrantCyan = Color(0xFF38BDF8);
  static const Color deepCobalt = Color(0xFF1D4ED8);

  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color electricLavender = Color(0xFFC4B5FD);
  static const Color vibrantLavender = Color(0xFFA78BFA);
  static const Color deepViolet = Color(0xFF6D28D9);

  // State Colors
  static const Color safeGreen = Color(0xFF10B981);
  static const Color safeGreenGlow = Color(0xFF34D399);
  static const Color safeGreenMuted = Color(0x2410B981);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberMuted = Color(0x24F59E0B);

  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color emergencyRedBright = Color(0xFFF87171);
  static const Color emergencyRedMuted = Color(0x24EF4444);

  static const Color infoBlue = Color(0xFF38BDF8);
  static const Color infoBlueMuted = Color(0x2438BDF8);

  // Text & Content
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Light Mode equivalents
  static const Color lightBackground = Color(0xFFF8F9FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF2F6);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}

/// Backward compatibility alias and standard AppColors
class AppColors {
  // Midnight Obsidian & Slate tokens
  static const Color midnightDarkBackground = SafeLoopColors.midnightDarkBackground;
  static const Color midnightDarkSurface = SafeLoopColors.midnightDarkSurface;
  static const Color midnightDarkSurfaceVariant = SafeLoopColors.midnightDarkSurfaceVariant;
  static const Color midnightDarkCard = SafeLoopColors.midnightDarkCard;
  static const Color midnightDarkCardBorder = SafeLoopColors.midnightDarkCardBorder;

  // Signal Cobalt & Ice Accents
  static const Color primaryCobalt = SafeLoopColors.primaryCobalt;
  static const Color electricCyan = SafeLoopColors.electricCyan;
  static const Color vibrantCyan = SafeLoopColors.vibrantCyan;
  static const Color deepCobalt = SafeLoopColors.deepCobalt;

  // Aliases
  static const Color primaryViolet = SafeLoopColors.primaryViolet;
  static const Color electricLavender = SafeLoopColors.electricLavender;
  static const Color vibrantLavender = SafeLoopColors.vibrantLavender;
  static const Color deepViolet = SafeLoopColors.deepViolet;

  // State & Status Colors
  static const Color safeGreen = SafeLoopColors.safeGreen;
  static const Color safeGreenGlow = SafeLoopColors.safeGreenGlow;
  static const Color safeGreenMuted = SafeLoopColors.safeGreenMuted;

  static const Color warningAmber = SafeLoopColors.warningAmber;
  static const Color warningAmberMuted = SafeLoopColors.warningAmberMuted;

  static const Color emergencyRed = SafeLoopColors.emergencyRed;
  static const Color emergencyRedBright = SafeLoopColors.emergencyRedBright;
  static const Color emergencyRedMuted = SafeLoopColors.emergencyRedMuted;

  static const Color infoBlue = SafeLoopColors.infoBlue;
  static const Color infoBlueMuted = SafeLoopColors.infoBlueMuted;

  // Text
  static const Color textPrimary = SafeLoopColors.textPrimary;
  static const Color textSecondary = SafeLoopColors.textSecondary;
  static const Color textMuted = SafeLoopColors.textMuted;

  // Light Mode
  static const Color lightBackground = SafeLoopColors.lightBackground;
  static const Color lightSurface = SafeLoopColors.lightSurface;
  static const Color lightSurfaceVariant = SafeLoopColors.lightSurfaceVariant;
  static const Color lightCardBorder = SafeLoopColors.lightCardBorder;
  static const Color lightTextPrimary = SafeLoopColors.lightTextPrimary;
  static const Color lightTextSecondary = SafeLoopColors.lightTextSecondary;
  static const Color lightTextMuted = SafeLoopColors.lightTextMuted;
}
