import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/design_tokens.dart';

enum AppThemeMode { system, light, dark, oled }

class AppearanceState {
  final AppThemeMode themeMode;
  final double fontSize;
  final Color bubbleColor;
  final String wallpaperName;

  AppearanceState({
    this.themeMode = AppThemeMode.system,
    this.fontSize = 15.0,
    this.bubbleColor = DesignTokens.primary,
    this.wallpaperName = 'Classic Doodle',
  });

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.oled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppearanceState copyWith({
    AppThemeMode? themeMode,
    double? fontSize,
    Color? bubbleColor,
    String? wallpaperName,
  }) {
    return AppearanceState(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      wallpaperName: wallpaperName ?? this.wallpaperName,
    );
  }
}

class AppearanceNotifier extends Notifier<AppearanceState> {
  static const _themeModeKey = 'app_theme_mode';
  static const _fontSizeKey = 'app_font_size';
  static const _bubbleColorKey = 'app_bubble_color';
  static const _wallpaperKey = 'app_wallpaper_name';

  @override
  AppearanceState build() {
    _loadFromPrefs();
    return AppearanceState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_themeModeKey);
      final size = prefs.getDouble(_fontSizeKey);
      final colorVal = prefs.getInt(_bubbleColorKey);
      final wall = prefs.getString(_wallpaperKey);

      AppThemeMode? mode;
      if (modeStr != null) {
        for (final m in AppThemeMode.values) {
          if (m.name == modeStr) {
            mode = m;
            break;
          }
        }
      }

      state = state.copyWith(
        themeMode: mode,
        fontSize: size,
        bubbleColor: colorVal != null ? Color(colorVal) : null,
        wallpaperName: wall,
      );
    } catch (_) {}
  }

  void setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {}
  }

  void setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, size);
    } catch (_) {}
  }

  void setBubbleColor(Color color) async {
    state = state.copyWith(bubbleColor: color);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bubbleColorKey, color.toARGB32());
    } catch (_) {}
  }

  void setWallpaper(String name) async {
    state = state.copyWith(wallpaperName: name);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_wallpaperKey, name);
    } catch (_) {}
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceState>(AppearanceNotifier.new);
