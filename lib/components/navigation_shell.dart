import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ai_onboarding_wizard_dialog.dart';
import '../components/brand.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';

/// The app's main shell: a five-item bottom navigation.
///
/// Tabs (per product spec):
///   Home · Chats (MurihSpace Favicon) · Center Action · Marketplace · You
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final role = auth.user?.role ?? UserRole.member;
    final isOnboarded = auth.user?.onboardingCompleted ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          if (auth.user != null && !isOnboarded && !_bannerDismissed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181A20) : const Color(0xFFF4F6F8),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2B2F38) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262933) : const Color(0xFFEAEFF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const BrandFavicon(size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Your Space Setup',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF111827),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set your profile, bio & preferences.',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => AiOnboardingWizardDialog.show(context),
                      child: const Text('Setup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _bannerDismissed = true),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: widget.navigationShell.currentIndex,
        role: role,
        onSelect: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

/// Custom five-item Telegram iOS bottom navigation bar with role-aware center tools tab.
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final UserRole role;
  final ValueChanged<int> onSelect;

  const _BottomBar({
    required this.currentIndex,
    required this.role,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final centerItem = switch (role) {
      UserRole.creator => const _BarItem(
          Icons.movie_creation_outlined,
          Icons.movie_creation_rounded,
          'Creator',
        ),
      UserRole.vendor => const _BarItem(
          Icons.storefront_outlined,
          Icons.storefront_rounded,
          'Vendor',
        ),
      _ => const _BarItem(
          Icons.widgets_outlined,
          Icons.widgets_rounded,
          'Tools',
        ),
    };

    final fourthItem = role == UserRole.creator
        ? const _BarItem(Icons.groups_outlined, Icons.groups_rounded, 'Communities')
        : const _BarItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Marketplace');

    final items = <_BarItem>[
      const _BarItem(Icons.explore_outlined, Icons.explore_rounded, 'Feed'),
      _BarItem(
        null,
        null,
        'Chats',
        builder: (selected, isDark) => BrandFavicon(
          size: 22,
          isDark: isDark,
          color: selected
              ? const Color(0xFF007AFF)
              : (isDark ? Colors.white : const Color(0xFF007AFF)),
        ),
      ),
      centerItem,
      fourthItem,
      const _BarItem(Icons.person_outline_rounded, Icons.person_rounded, 'You'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _barItem(context, items[i], i, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem(BuildContext context, _BarItem item, int index, bool isDark) {
    final selected = index == currentIndex;
    final activeColor = const Color(0xFF007AFF);
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return InkWell(
      onTap: () => onSelect(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? activeColor.withValues(alpha: 0.2) : activeColor.withValues(alpha: 0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: item.builder != null
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: Opacity(
                        opacity: selected ? 1.0 : (isDark ? 0.95 : 0.85),
                        child: item.builder!(selected, isDark),
                      ),
                    ),
                  )
                : Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected ? activeColor : inactiveColor,
                    size: 22,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  final IconData? icon;
  final IconData? selectedIcon;
  final String label;
  final Widget Function(bool selected, bool isDark)? builder;

  const _BarItem(this.icon, this.selectedIcon, this.label, {this.builder});
}
