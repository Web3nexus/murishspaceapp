import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/appearance_provider.dart';

/// Telegram iOS style Appearance & Theme Customization screen connected to appearanceProvider.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFF5856D6),
      const Color(0xFFFF2D55),
      const Color(0xFFAF52DE),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Appearance & Themes',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Live Chat Bubble Preview Card
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'LIVE CHAT PREVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Hey! How does MurihSpace look?',
                      style: TextStyle(fontSize: state.fontSize, color: textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: state.bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'It looks stunning with custom text sizes & bubble colors! ✨',
                      style: TextStyle(fontSize: state.fontSize, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme Selector Group
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'COLOR THEME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _themeTile('System Auto-detect', AppThemeMode.system, state.themeMode, notifier, textPrimary),
                const Divider(height: 1, indent: 16),
                _themeTile('Light Mode (Day)', AppThemeMode.light, state.themeMode, notifier, textPrimary),
                const Divider(height: 1, indent: 16),
                _themeTile('Dark Mode (Night OLED)', AppThemeMode.dark, state.themeMode, notifier, textPrimary),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Text Size Slider Group
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'TEXT SIZE (${state.fontSize.round()} pt)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('A', style: TextStyle(fontSize: 12, color: textSecondary)),
                    Text('${state.fontSize.round()} pt', style: TextStyle(fontWeight: FontWeight.bold, color: state.bubbleColor)),
                    Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                Slider(
                  value: state.fontSize,
                  min: 12,
                  max: 20,
                  divisions: 8,
                  activeColor: state.bubbleColor,
                  onChanged: (v) => notifier.setFontSize(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chat Bubble Palette Group
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ACCENT & BUBBLE COLOR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: colors.map((c) {
                final isSelected = state.bubbleColor == c;
                return InkWell(
                  onTap: () => notifier.setBubbleColor(c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeTile(String label, AppThemeMode mode, AppThemeMode currentMode, AppearanceNotifier notifier, Color textPrimary) {
    final selected = currentMode == mode;
    return ListTile(
      onTap: () => notifier.setThemeMode(mode),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: textPrimary,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 22)
          : null,
    );
  }
}
