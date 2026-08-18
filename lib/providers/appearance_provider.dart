import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { system, light, dark, oled }

class AppearanceState {
  final AppThemeMode themeMode;
  final double fontSize;
  final Color bubbleColor;
  final String wallpaperName;

  AppearanceState({
    this.themeMode = AppThemeMode.system,
    this.fontSize = 15.0,
    this.bubbleColor = const Color(0xFF007AFF),
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
  @override
  AppearanceState build() {
    return AppearanceState();
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
  }

  void setBubbleColor(Color color) {
    state = state.copyWith(bubbleColor: color);
  }

  void setWallpaper(String name) {
    state = state.copyWith(wallpaperName: name);
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceState>(AppearanceNotifier.new);
