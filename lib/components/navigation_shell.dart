import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ai_onboarding_wizard_dialog.dart';
import '../components/brand.dart';
import '../components/murih_icon.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'profile_drawer.dart';

/// Global scaffold key for the main shell, used to open the profile drawer
/// from the profile ("You") page's app bar.
final GlobalKey<ScaffoldState> appShellScaffoldKey = GlobalKey<ScaffoldState>();

/// The app's main persistent shell with the unified five-item fintech/social navigation:
/// 1. Home · 2. Discover · 3. Create (Elevated +) · 4. Messages (BrandFavicon) · 5. Profile
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _bannerDismissed = false;

  void _showQuickCreateMenu(BuildContext context, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create on MurihSpace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _createActionTile(
                      context: ctx,
                      title: 'Create Post',
                      subtitle: 'Photo, text & media',
                      iconName: 'Edit Square',
                      color: DesignTokens.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.navigationShell.goBranch(2);
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _createActionTile(
                      context: ctx,
                      title: 'Upload Video',
                      subtitle: 'Short reel or video',
                      iconName: 'Video',
                      color: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.navigationShell.goBranch(2);
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _createActionTile(
                      context: ctx,
                      title: 'Go Live',
                      subtitle: 'Broadcast to followers',
                      iconName: 'Camera',
                      color: const Color(0xFFDC2626),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/live/start');
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _createActionTile(
                      context: ctx,
                      title: 'Creator Studio',
                      subtitle: 'Publishing & tools',
                      iconName: 'Camera',
                      color: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.navigationShell.goBranch(2);
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String iconName,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: MurihIcon(iconName, size: 20, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF17202B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final unreadMessages = ref.watch(conversationsProvider).unreadTotal;
    final isOnboarded = auth.user?.onboardingCompleted ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: appShellScaffoldKey,
      drawer: const ProfileDrawer(),
      drawerEnableOpenDragGesture: false,
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
        unreadMessages: unreadMessages,
        onSelect: (index) {
          if (index == 2 && widget.navigationShell.currentIndex == 2) {
            _showQuickCreateMenu(context, isDark);
            return;
          }
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        onCreateLongPress: () => _showQuickCreateMenu(context, isDark),
      ),
    );
  }
}

/// Unified 5-Item Persistent Mobile Navigation Bar
/// 1: Home · 2: Discover · 3: Create (Elevated +) · 4: Messages (BrandFavicon) · 5: Profile
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final int unreadMessages;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateLongPress;

  const _BottomBar({
    required this.currentIndex,
    required this.unreadMessages,
    required this.onSelect,
    required this.onCreateLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const brandBlue = DesignTokens.primary; // #1A68D4
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final bgColor = isDark ? const Color(0xFF121620) : Colors.white;
    final borderColor = isDark ? const Color(0xFF222B3D) : const Color(0xFFE4E7EC);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // 1. Home (Feed)
              Expanded(
                child: _navItem(
                  index: 0,
                  label: 'Home',
                  iconName: 'Home',
                  isSelected: currentIndex == 0,
                  brandBlue: brandBlue,
                  inactiveColor: inactiveColor,
                ),
              ),

              // 2. Discover
              Expanded(
                child: _navItem(
                  index: 1,
                  label: 'Discover',
                  iconName: 'Discovery',
                  isSelected: currentIndex == 1,
                  brandBlue: brandBlue,
                  inactiveColor: inactiveColor,
                ),
              ),

              // 3. Central Elevated Create Action (+)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(2),
                  onLongPress: onCreateLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: brandBlue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: brandBlue.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Messages (Preserved BrandFavicon system chat icon with unread badge)
              Expanded(
                child: _chatNavItem(
                  index: 3,
                  label: 'Messages',
                  unreadCount: unreadMessages,
                  isSelected: currentIndex == 3,
                  brandBlue: brandBlue,
                  inactiveColor: inactiveColor,
                  isDark: isDark,
                ),
              ),

              // 5. Profile
              Expanded(
                child: _navItem(
                  index: 4,
                  label: 'Profile',
                  iconName: 'Profile',
                  isSelected: currentIndex == 4,
                  brandBlue: brandBlue,
                  inactiveColor: inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required String label,
    required String iconName,
    required bool isSelected,
    required Color brandBlue,
    required Color inactiveColor,
  }) {
    final activeColor = isSelected ? brandBlue : inactiveColor;
    return InkWell(
      onTap: () => onSelect(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MurihIcon(iconName, size: 22, color: activeColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: activeColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatNavItem({
    required int index,
    required String label,
    required int unreadCount,
    required bool isSelected,
    required Color brandBlue,
    required Color inactiveColor,
    required bool isDark,
  }) {
    final activeColor = isSelected ? brandBlue : inactiveColor;
    return InkWell(
      onTap: () => onSelect(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Center(
                  child: BrandFavicon(
                    size: 22,
                    isDark: isDark,
                    color: isSelected ? brandBlue : inactiveColor,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF121620) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: activeColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
