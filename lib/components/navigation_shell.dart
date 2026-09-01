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
  bool _wizardAutoShown = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final role = auth.user?.role ?? UserRole.member;
    final isOnboarded = auth.user?.onboardingCompleted ?? true;

    if (auth.user != null && !isOnboarded && !_wizardAutoShown) {
      _wizardAutoShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AiOnboardingWizardDialog.show(context);
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          if (auth.user != null && !isOnboarded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const BrandFavicon(size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Your profile space is incomplete — Complete verification setup to activate account.',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF007AFF),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => AiOnboardingWizardDialog.show(context),
                      child: const Text('Setup Wizard', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
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
        customWidget: BrandFavicon(size: 22, isDark: isDark),
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                  ? (isDark ? activeColor.withOpacity(0.2) : activeColor.withOpacity(0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: item.customWidget != null
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: Opacity(
                        opacity: selected ? 1.0 : 0.65,
                        child: item.customWidget,
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
  final Widget? customWidget;

  const _BarItem(this.icon, this.selectedIcon, this.label, {this.customWidget});
}
