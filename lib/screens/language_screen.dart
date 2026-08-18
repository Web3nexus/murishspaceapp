import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';

/// Telegram iOS style Language Selection screen connected to languageProvider.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(languageProvider);
    final notifier = ref.read(languageProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          state.tr('language'),
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SELECT APP & WEB LANGUAGE',
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: supportedLanguages.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (ctx, i) {
                final lang = supportedLanguages[i];
                final selected = lang.code == state.currentLanguage.code;
                return ListTile(
                  onTap: () {
                    notifier.setLanguage(lang);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('App language changed to ${lang.nativeName} (${lang.flag})'),
                        backgroundColor: const Color(0xFF34C759),
                      ),
                    );
                  },
                  leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    lang.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 22)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
