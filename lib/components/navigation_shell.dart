import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';

/// The app's main shell: a five-item bottom navigation.
///
/// Tabs (per product spec):
///   Chats · Communities · Create (center action) · Discover · You
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final role = auth.user?.role ?? UserRole.member;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        role: role,
        onSelect: (index) {
          if (index == _BottomBar.createIndex) {
            _openCreateSheet(context, role);
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }

  /// Central "Create" action. Options are role/permission aware.
  void _openCreateSheet(BuildContext context, UserRole role) {
    final canStream = role.isSeller || role == UserRole.admin;
    final canSell = role.isSeller;
    final options = <_CreateOption>[
      _CreateOption(Icons.article_outlined, 'New post', 'Share a post to the feed', const Color(0xFF38A8D8)),
      _CreateOption(Icons.photo_camera_outlined, 'New story', 'Share a disappearing story', const Color(0xFF8B5CF6)),
      if (canStream) _CreateOption(Icons.radio, 'Go live', 'Stream to your audience', const Color(0xFFDC4C64)),
      if (canStream) _CreateOption(Icons.record_voice_over_outlined, 'Start audio room', 'Host a live conversation', const Color(0xFF22A06B)),
      _CreateOption(Icons.group_add_outlined, 'Create community', 'Build a space to belong', const Color(0xFF237DA7)),
      if (canStream) _CreateOption(Icons.campaign_outlined, 'Create channel', 'Broadcast to followers', const Color(0xFFF59E0B)),
      if (canSell) _CreateOption(Icons.sell_outlined, 'Add product', 'List something to sell', const Color(0xFFDC4C64)),
      _CreateOption(Icons.event_outlined, 'Create event', 'Plan a meetup or event', const Color(0xFF22A06B)),
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text('Create', style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'What would you like to create?',
                style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: option.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(option.icon, color: option.color, size: 20),
                ),
                title: Text(option.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(option.subtitle, style: const TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${option.title} — coming in a later phase')),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _CreateOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _CreateOption(this.icon, this.title, this.subtitle, this.color);
}

/// Custom five-item bottom bar with a raised central Create button.
class _BottomBar extends StatelessWidget {
  static const int createIndex = 2;

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
    final items = <_BarItem>[
      _BarItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
      _BarItem(Icons.groups_outlined, Icons.groups, 'Communities'),
      _BarItem(Icons.add_circle_outline, Icons.add_circle, 'Create'),
      _BarItem(Icons.explore_outlined, Icons.explore, 'Discover'),
      _BarItem(Icons.person_outline, Icons.person, 'You'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: DesignTokens.surface,
        border: Border(top: BorderSide(color: DesignTokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: DesignTokens.navBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _barItem(context, items[i], i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem(BuildContext context, _BarItem item, int index) {
    final selected = index == currentIndex;
    final isCreate = index == createIndex;

    final color = selected ? DesignTokens.primaryDark : DesignTokens.textSecondary;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: color,
    );

    if (isCreate) {
      return InkWell(
        onTap: () => onSelect(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [DesignTokens.primary, DesignTokens.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            Text(item.label, style: labelStyle),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => onSelect(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.selectedIcon : item.icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(item.label, style: labelStyle),
        ],
      ),
    );
  }
}

class _BarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _BarItem(this.icon, this.selectedIcon, this.label);
}
