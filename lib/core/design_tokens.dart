import 'package:flutter/material.dart';

/// MurihSpace brand design tokens (light-mode-first).
/// Source: platform design system (navy + sky blue identity).
abstract final class DesignTokens {
  // Palette
  static const Color sidebar = Color(0xFF102840);
  static const Color sidebarForeground = Color(0xE6F7FAFC); // rgba(247,250,252,.90)
  static const Color sidebarPrimary = Color(0xFF38A8D8);
  static const Color sidebarAccent = Color(0x14FFFFFF); // rgba(255,255,255,.08)

  static const Color background = Color(0xFFF7FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F6FA);

  static const Color primary = Color(0xFF38A8D8);
  static const Color primaryDark = Color(0xFF237DA7);
  static const Color primarySoft = Color(0xFFE8F6FC);

  static const Color navy = Color(0xFF102840);
  static const Color textPrimary = Color(0xFF102840);
  static const Color textSecondary = Color(0xFF61758A);
  static const Color border = Color(0xFFDCE7EF);

  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC4C64);

  // Radii
  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 18;

  // Navigation
  static const double navBarHeight = 64;
}
