import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: DesignTokens.primary,
      brightness: Brightness.light,
      primary: DesignTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: DesignTokens.primarySoft,
      onPrimaryContainer: DesignTokens.primaryDark,
      secondary: DesignTokens.navy,
      onSecondary: Colors.white,
      surface: DesignTokens.surface,
      onSurface: DesignTokens.textPrimary,
      error: DesignTokens.danger,
      outline: DesignTokens.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DesignTokens.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.surface,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: const BorderSide(color: DesignTokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.surface,
        indicatorColor: DesignTokens.primarySoft,
        height: DesignTokens.navBarHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? DesignTokens.primaryDark : DesignTokens.textSecondary,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: DesignTokens.border, thickness: 1),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: DesignTokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 24),
        titleMedium: TextStyle(color: DesignTokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        bodyMedium: TextStyle(color: DesignTokens.textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    // Dark mode ships in a later phase; provide a token-consistent dark variant now.
    final scheme = ColorScheme.fromSeed(
      seedColor: DesignTokens.primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF5BB8E2),
      onPrimary: DesignTokens.navy,
      surface: const Color(0xFF0E1E30),
      onSurface: const Color(0xFFEAF2F9),
      error: DesignTokens.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF081826),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E1E30),
        foregroundColor: Color(0xFFEAF2F9),
        elevation: 0,
      ),
    );
  }
}
