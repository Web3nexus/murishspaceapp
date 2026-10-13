import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/router.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../screens/settings_screen.dart';
import 'account_switcher_sheet.dart';

/// Slide-out menu for the profile ("You") page.
///
/// Hosts account switching (Add account, Switch profile), quick access to
/// Saved, every Settings section, and a pinned Log Out at the bottom.
class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  void _closeDrawer(BuildContext context) => Navigator.of(context).pop();

  void _go(BuildContext context, String location) {
    final root = rootNavigatorKey.currentContext;
    _closeDrawer(context);
    if (root != null) GoRouter.of(root).push(location);
  }

  Future<void> _openSwitcher(BuildContext context) async {
    final root = rootNavigatorKey.currentContext;
    _closeDrawer(context);
    if (root != null) await showAccountSwitcherSheet(root);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final root = rootNavigatorKey.currentContext;
    _closeDrawer(context);
    await ref.read(authProvider.notifier).logout();
    if (root != null && root.mounted) GoRouter.of(root).go('/auth/login');
  }

  /// Switches the active profile mode (Member ↔ Creator ↔ Vendor).
  Future<void> _switchMode(BuildContext context, WidgetRef ref, UserRole target) async {
    final root = rootNavigatorKey.currentContext;
    final messenger = root != null ? ScaffoldMessenger.maybeOf(root) : null;
    _closeDrawer(context);
    final ok = await ref.read(authProvider.notifier).switchRole(target);
    if (ok) {
      if (root != null && root.mounted) GoRouter.of(root).go('/app');
      messenger?.showSnackBar(
        SnackBar(content: Text('Switched to ${target.label} profile')),
      );
    } else {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not switch profile. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'MurihSpace User';
    final username = (user?.username.isNotEmpty ?? false) ? user!.username : 'user';
    final role = user?.role ?? UserRole.member;
    final avatar = user?.avatarUrl != null ? ApiClient.resolveUrl(user!.avatarUrl) : null;

    // Profile modes the account can operate in: a business profile it holds or
    // has been approved for, plus the personal Member profile only while the
    // account has never upgraded. Once upgraded to Creator/Vendor the plain
    // Member mode disappears and the account switches between Creator/Vendor.
    final history = ref.watch(roleUpgradeProvider).history;
    final upgraded = role == UserRole.creator ||
        role == UserRole.vendor ||
        role == UserRole.admin ||
        history.any((app) =>
            app.status == 'approved' &&
            (app.requestedRole == 'creator' || app.requestedRole == 'vendor'));
    final modes = <UserRole>{};
    if (role == UserRole.admin) {
      modes.addAll(const [UserRole.creator, UserRole.vendor, UserRole.admin]);
    } else if (role != UserRole.member) {
      modes.add(role);
    }
    for (final app in history) {
      if (app.status == 'approved') modes.add(UserRole.fromApi(app.requestedRole));
    }
    if (!upgraded) modes.add(UserRole.member);
    final orderedModes = [
      ...UserRole.profileModes.where(modes.contains),
      if (modes.contains(UserRole.admin)) UserRole.admin,
    ];

    return Drawer(
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────
            InkWell(
              onTap: () => _closeDrawer(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                      backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                      child: avatar == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: DesignTokens.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignTokens.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),

            // ── Scrollable body ────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  // Profile mode switcher (Member ↔ Creator ↔ Vendor)
                  if (orderedModes.length > 1) ...[
                    _sectionLabel('Switch profile type', textSecondary),
                    ...orderedModes.map(
                      (m) => _ModeTile(
                        role: m,
                        isCurrent: m == role,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () => _switchMode(context, ref, m),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: borderColor),
                    ),
                  ],

                  // Account actions
                  _DrawerTile(
                    icon: Icons.person_add_alt_1_rounded,
                    iconBg: const Color(0xFF34C759),
                    title: 'Add account',
                    textPrimary: textPrimary,
                    onTap: () => _go(context, '/add-account'),
                  ),
                  _DrawerTile(
                    icon: Icons.swap_horiz_rounded,
                    iconBg: const Color(0xFF5856D6),
                    title: 'Switch account',
                    textPrimary: textPrimary,
                    onTap: () => _openSwitcher(context),
                  ),
                  _DrawerTile(
                    icon: Icons.bookmark_rounded,
                    iconBg: DesignTokens.primary,
                    title: 'Saved',
                    textPrimary: textPrimary,
                    onTap: () => _go(context, '/app/saved'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: borderColor),
                  ),

                  // Settings sections (Log Out rendered separately below)
                  ...buildSettingsSections(
                    context,
                    ref,
                    includeLogout: false,
                    onBeforeNavigate: () => _closeDrawer(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            Divider(height: 1, color: borderColor),
            ListTile(
              onTap: () => _logout(context, ref),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionLabel(String text, Color color) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color,
      ),
    ),
  );
}

IconData _modeIcon(UserRole role) => switch (role) {
      UserRole.member => Icons.person_rounded,
      UserRole.creator => Icons.auto_awesome_rounded,
      UserRole.vendor => Icons.storefront_rounded,
      UserRole.admin => Icons.admin_panel_settings_rounded,
    };

Color _modeColor(UserRole role) => switch (role) {
      UserRole.member => const Color(0xFF5856D6),
      UserRole.creator => const Color(0xFF9C27B0),
      UserRole.vendor => const Color(0xFF00897B),
      UserRole.admin => const Color(0xFFDC2626),
    };

class _ModeTile extends StatelessWidget {
  final UserRole role;
  final bool isCurrent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _ModeTile({
    required this.role,
    required this.isCurrent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _modeColor(role);
    return ListTile(
      onTap: isCurrent ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Icon(_modeIcon(role), color: Colors.white, size: 18),
      ),
      title: Text(
        role.label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      trailing: isCurrent
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.check_circle_rounded, size: 18, color: color),
              ],
            )
          : Icon(Icons.swap_horiz_rounded, size: 20, color: textSecondary),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Color textPrimary;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
    );
  }
}
