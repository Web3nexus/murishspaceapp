import 'package:flutter/material.dart';

/// MurihSpace unified brand design tokens (Telegram / WhatsApp / X inspired density).
abstract final class DesignTokens {
  // Brand Palette
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0056B3);
  static const Color primarySoft = Color(0x1F007AFF);
  static const Color navy = Color(0xFF102840);
  static const Color sidebar = Color(0xFF102840);

  // Semantic Light Surfaces
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFEFEFF4);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF8E8E93);
  static const Color lightBorder = Color(0xFFE5E5EA);

  // Semantic Dark Surfaces (OLED Inspired)
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceSecondary = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkBorder = Color(0xFF38383A);

  // Status & Feature Identifiers
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color danger = Color(0xFFFF3B30);
  static const Color escrow = Color(0xFF007AFF);
  static const Color verified = Color(0xFF007AFF);
  static const Color creator = Color(0xFFFF9500);
  static const Color vendor = Color(0xFF5856D6);

  // Radius Scale
  static const double rTiny = 6.0;
  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 16.0;
  static const double rSheet = 20.0;
  static const double rPill = 999.0;

  // Legacy Radius aliases for compatibility
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // Navigation
  static const double navBarHeight = 60.0;

  // Legacy Static Color Aliases
  static const Color background = Color(0xFFF7FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F6FA);
  static const Color textPrimary = Color(0xFF102840);
  static const Color textSecondary = Color(0xFF61758A);
  static const Color border = Color(0xFFDCE7EF);

  // Dynamic Helpers
  static Color bgOf(bool isDark) => isDark ? darkBg : lightBg;
  static Color surfaceOf(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surfaceSecondaryOf(bool isDark) => isDark ? darkSurfaceSecondary : lightSurfaceSecondary;
  static Color textPrimaryOf(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondaryOf(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color borderOf(bool isDark) => isDark ? darkBorder : lightBorder;
}
