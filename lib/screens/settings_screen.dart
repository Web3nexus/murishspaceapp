import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/feature_flag_provider.dart';
import '../providers/language_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final flags = ref.watch(featureFlagProvider);
    final langState = ref.watch(languageProvider);
    final user = auth.user;
    final role = user?.role ?? UserRole.member;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Group 1: Profile & Wallet ────────────────────────────
          _SettingsCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _SettingsTile(
                iconBg: const Color(0xFFFF3B30),
                icon: Icons.person_rounded,
                title: 'Edit Profile',
                isDark: isDark,
                onTap: () => context.push('/profile'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF34C759),
                icon: Icons.people_rounded,
                title: 'Friends & Connections',
                badgeText: 'FRIENDS',
                badgeColor: const Color(0xFF34C759),
                isDark: isDark,
                onTap: () => context.push('/friends'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF007AFF),
                icon: Icons.account_balance_wallet_rounded,
                title: 'Wallet & Escrow',
                badgeText: '\$${user?.coins ?? 0} MSH',
                badgeColor: const Color(0xFF34C759),
                isDark: isDark,
                onTap: () => context.push('/wallet'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.campaign_rounded,
                title: 'Creator Hub & Brand Deals',
                badgeText: !flags.isEnabled('brand_deals')
                    ? 'DISABLED'
                    : ((role == UserRole.creator || role == UserRole.admin) ? 'HOT' : '🔒 LOCKED'),
                badgeColor: !flags.isEnabled('brand_deals')
                    ? Colors.grey
                    : ((role == UserRole.creator || role == UserRole.admin) ? const Color(0xFFFF9500) : Colors.grey),
                isDark: isDark,
                onTap: () {
                  if (!flags.isEnabled('brand_deals')) {
                    AppBottomSheet.showNotice(
                      context: context,
                      title: 'Feature Temporarily Disabled',
                      message: 'Brand Deals Marketplace is currently disabled by admin or rolling out soon.',
                    );
                    return;
                  }
                  if (role == UserRole.creator || role == UserRole.admin) {
                    context.push('/brand-deals');
                  } else {
                    _showRoleLockedDialog(
                      context,
                      'Creator Hub & Brand Deals',
                      'This feature is exclusively for Verified Creators. Apply for a Creator account to accept brand deals, receive MSH gifts, and earn locked escrow payouts.',
                    );
                  }
                },
              ),
              _SettingsTile(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.storefront_rounded,
                title: 'Vendor Store & Inventory',
                badgeText: !flags.isEnabled('vendor_store')
                    ? 'DISABLED'
                    : ((role == UserRole.vendor || role == UserRole.admin) ? 'ACTIVE' : '🔒 LOCKED'),
                badgeColor: !flags.isEnabled('vendor_store')
                    ? Colors.grey
                    : ((role == UserRole.vendor || role == UserRole.admin) ? const Color(0xFF5856D6) : Colors.grey),
                isDark: isDark,
                onTap: () {
                  if (!flags.isEnabled('vendor_store')) {
                    AppBottomSheet.showNotice(
                      context: context,
                      title: 'Feature Temporarily Disabled',
                      message: 'Vendor Store Mode is currently disabled by admin or rolling out soon.',
                    );
                    return;
                  }
                  if (role == UserRole.vendor || role == UserRole.admin) {
                    context.push('/marketplace');
                  } else {
                    _showRoleLockedDialog(
                      context,
                      'Vendor Store',
                      'This feature is exclusively for Verified Vendors. Apply for a Vendor account to open your storefront, manage inventory, and receive escrow orders.',
                    );
                  }
                },
              ),
              _SettingsTile(
                iconBg: const Color(0xFFAF52DE),
                icon: Icons.link_rounded,
                title: 'Link in Bio Builder',
                badgeText: !flags.isEnabled('link_in_bio') ? 'DISABLED' : 'HUB 🔗',
                badgeColor: !flags.isEnabled('link_in_bio') ? Colors.grey : const Color(0xFFAF52DE),
                isDark: isDark,
                onTap: () {
                  if (!flags.isEnabled('link_in_bio')) {
                    AppBottomSheet.showNotice(
                      context: context,
                      title: 'Feature Temporarily Disabled',
                      message: 'Link in Bio Builder is currently disabled by admin or rolling out soon.',
                    );
                    return;
                  }
                  context.push('/link-in-bio');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Group 2: Messages & Communication ──────────────────
          _SettingsCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _SettingsTile(
                iconBg: const Color(0xFF34C759),
                icon: Icons.bookmark_rounded,
                title: 'Saved Messages',
                isDark: isDark,
                onTap: () => context.push('/app/saved'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF30B0C7),
                icon: Icons.phone_in_talk_rounded,
                title: 'Recent Calls',
                isDark: isDark,
                onTap: () => context.push('/app/calls'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.devices_rounded,
                title: 'Devices & Active Sessions',
                trailingText: 'Active >',
                isDark: isDark,
                onTap: () => context.push('/profile/devices'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.folder_rounded,
                title: 'Chat Folders',
                isDark: isDark,
                onTap: () => context.push('/profile/chat-folders'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF007AFF),
                icon: Icons.mark_email_read_rounded,
                title: 'Chat & Email Backup',
                badgeText: 'EMAIL',
                badgeColor: const Color(0xFF007AFF),
                isDark: isDark,
                onTap: () => context.push('/profile/chat-backup'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Group 3: Preferences & Security ──────────────────────
          _SettingsCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _SettingsTile(
                iconBg: const Color(0xFFFF2D55),
                icon: Icons.notifications_active_rounded,
                title: 'Notifications and Sounds',
                isDark: isDark,
                onTap: () => context.push('/profile/notifications'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFF8E8E93),
                icon: Icons.lock_rounded,
                title: 'Privacy and Security',
                isDark: isDark,
                onTap: () => context.push('/profile/security'),
              ),
              if (role == UserRole.admin) ...[
                _SettingsTile(
                  iconBg: const Color(0xFFFF3B30),
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Staff & Admin Moderation CMS',
                  trailingText: 'Monitor >',
                  isDark: isDark,
                  onTap: () => context.push('/admin/moderation'),
                ),
              ],
              _SettingsTile(
                iconBg: const Color(0xFF5AC8FA),
                icon: Icons.brightness_6_rounded,
                title: 'Appearance',
                trailingText: isDark ? 'Dark >' : 'Light >',
                isDark: isDark,
                onTap: () => context.push('/profile/appearance'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFFAF52DE),
                icon: Icons.language_rounded,
                title: 'Language & Translation',
                trailingText: '${langState.currentLanguage.flag} ${langState.currentLanguage.name} >',
                isDark: isDark,
                onTap: () => context.push('/profile/language'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Group 4: Verification & Role Upgrade ──────────────────
          _SettingsCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _SettingsTile(
                iconBg: const Color(0xFFFFCC00),
                icon: Icons.verified_rounded,
                title: 'KYC & Verification',
                isDark: isDark,
                onTap: () => context.push('/kyc'),
              ),
              _SettingsTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.workspace_premium_rounded,
                title: 'Verification Badge',
                isDark: isDark,
                onTap: () => context.push('/verification-badge'),
              ),
              if (Permissions.roleHas(role, 'role.upgrade.apply'))
                _SettingsTile(
                  iconBg: const Color(0xFF007AFF),
                  icon: Icons.card_giftcard_rounded,
                  title: 'Gifts Catalogue',
                  isDark: isDark,
                  onTap: () => context.push('/gifts'),
                ),
              if (Permissions.roleHas(role, 'role.upgrade.apply'))
                _SettingsTile(
                  iconBg: const Color(0xFF34C759),
                  icon: Icons.upgrade_rounded,
                  title: 'Upgrade Account',
                  isDark: isDark,
                  onTap: () => context.push('/upgrade-account'),
                ),
              if (Permissions.roleHas(role, 'ai_onboarding.access'))
                _SettingsTile(
                  iconBg: const Color(0xFF5856D6),
                  icon: Icons.hub_rounded,
                  title: 'Social Accounts',
                  isDark: isDark,
                  onTap: () => context.push('/social-accounts'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Group 5: Session / Log Out ────────────────────────────────────
          _SettingsCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              ListTile(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: const Center(
                  child: Text(
                    'Log Out',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showRoleLockedDialog(BuildContext context, String featureTitle, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFFF9500)),
            const SizedBox(width: 8),
            Expanded(child: Text(featureTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(ctx);
              router.push('/upgrade-account');
            },
            child: const Text('Upgrade Account'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCardGroup extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg;
  final Color dividerColor;

  const _SettingsCardGroup({
    required this.children,
    required this.cardBg,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> divided = [];
    for (int i = 0; i < children.length; i++) {
      divided.add(children[i]);
      if (i < children.length - 1) {
        divided.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(height: 1, color: dividerColor),
          ),
        );
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: divided),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String? trailingText;
  final String? badgeText;
  final Color? badgeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.iconBg,
    required this.icon,
    required this.title,
    this.trailingText,
    this.badgeText,
    this.badgeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? const Color(0xFF007AFF)).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText!,
                style: TextStyle(
                  color: badgeColor ?? const Color(0xFF007AFF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 20,
            ),
        ],
      ),
    );
  }
}
