import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/language_provider.dart';
import '../providers/social_account_provider.dart';
import '../providers/wallet_provider.dart';

/// Telegram iOS Inset Grouped Settings & Profile screen.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
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
          'Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends'),
            icon: Icon(
              Icons.people_outline_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'Friends & Connections',
          ),
          TextButton(
            onPressed: () => context.push('/profile'),
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Group 0: Header Profile Card ─────────────────────────────────
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _initials(user?.name ?? '?'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user?.name ?? 'MurihSpace User',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF007AFF),
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${(user?.username != null && user!.username.isNotEmpty) ? user.username : (user?.name ?? 'user').toLowerCase().replaceAll(' ', '_')}',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showAccountSwitcherSheet(context, isDark, role),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${role.label} Mode',
                                      style: const TextStyle(
                                        color: Color(0xFF007AFF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF007AFF)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 12),
                  // Quick stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _profileStat('Posts', '12', isDark),
                      _profileStat('Followers', '348', isDark),
                      _profileStat('Following', '120', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Group 1: Profile, Creator & Wallet ────────────────────────────
          _TelegramCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _TelegramTile(
                iconBg: const Color(0xFFFF3B30),
                icon: Icons.person_rounded,
                title: 'My Profile',
                isDark: isDark,
                onTap: () => context.push('/profile'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFF34C759),
                icon: Icons.people_rounded,
                title: 'Friends & Connections',
                badgeText: '2 NEW',
                badgeColor: const Color(0xFF34C759),
                isDark: isDark,
                onTap: () => context.push('/friends'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFF007AFF),
                icon: Icons.account_balance_wallet_rounded,
                title: 'Wallet & Escrow',
                badgeText: 'ESCROW',
                badgeColor: const Color(0xFF34C759),
                isDark: isDark,
                onTap: () => context.push('/wallet'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.campaign_rounded,
                title: 'Creator Hub & Brand Deals',
                badgeText: (role == UserRole.creator || role == UserRole.admin) ? 'HOT' : '🔒 LOCKED',
                badgeColor: (role == UserRole.creator || role == UserRole.admin) ? const Color(0xFFFF9500) : Colors.grey,
                isDark: isDark,
                onTap: () {
                  if (role == UserRole.creator || role == UserRole.admin) {
                    context.push('/brand-deals');
                  } else {
                    _showRoleLockedDialog(
                      context,
                      'Creator Hub & Brand Deals',
                      'This feature is exclusively for Verified Creators. Apply for a Creator account to accept brand deals, receive MSH gifts, and earn locked escrow payouts.',
                      'Creator',
                    );
                  }
                },
              ),
              _TelegramTile(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.storefront_rounded,
                title: 'Vendor Store & Inventory',
                badgeText: (role == UserRole.vendor || role == UserRole.admin) ? 'ACTIVE' : '🔒 LOCKED',
                badgeColor: (role == UserRole.vendor || role == UserRole.admin) ? const Color(0xFF5856D6) : Colors.grey,
                isDark: isDark,
                onTap: () {
                  if (role == UserRole.vendor || role == UserRole.admin) {
                    context.push('/marketplace');
                  } else {
                    _showRoleLockedDialog(
                      context,
                      'Vendor Store',
                      'This feature is exclusively for Verified Vendors. Apply for a Vendor account to open your storefront, manage inventory, and receive escrow orders.',
                      'Vendor',
                    );
                  }
                },
              ),
              _TelegramTile(
                iconBg: const Color(0xFFAF52DE),
                icon: Icons.link_rounded,
                title: 'Link in Bio Builder',
                badgeText: 'HUB 🔗',
                badgeColor: const Color(0xFFAF52DE),
                isDark: isDark,
                onTap: () => context.push('/link-in-bio'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Creator & Vendor Analytics Widgets ──────────────────────────────
          if (role == UserRole.creator || role == UserRole.admin) ...[
            _CreatorMediaKitCard(cardBg: cardBg, isDark: isDark),
            const SizedBox(height: 16),
          ],
          if (role == UserRole.vendor || role == UserRole.admin) ...[
            _VendorStoreSummaryCard(cardBg: cardBg, isDark: isDark),
            const SizedBox(height: 16),
          ],

          // ── Group 2: Messages & Devices ──────────────────────────────────
          _TelegramCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _TelegramTile(
                iconBg: const Color(0xFF34C759),
                icon: Icons.bookmark_rounded,
                title: 'Saved Messages',
                isDark: isDark,
                onTap: () => context.push('/app/saved'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFF30B0C7),
                icon: Icons.phone_in_talk_rounded,
                title: 'Recent Calls',
                isDark: isDark,
                onTap: () => context.push('/app/calls'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.devices_rounded,
                title: 'Devices',
                trailingText: '3 >',
                isDark: isDark,
                onTap: () => context.push('/profile/devices'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.folder_rounded,
                title: 'Chat Folders',
                isDark: isDark,
                onTap: () => context.push('/profile/chat-folders'),
              ),
              _TelegramTile(
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

          // ── Group 3: Preferences & Security ──────────────────────────────
          _TelegramCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _TelegramTile(
                iconBg: const Color(0xFFFF2D55),
                icon: Icons.notifications_active_rounded,
                title: 'Notifications and Sounds',
                isDark: isDark,
                onTap: () => context.push('/profile/notifications'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFF8E8E93),
                icon: Icons.lock_rounded,
                title: 'Privacy and Security',
                isDark: isDark,
                onTap: () => context.push('/profile/security'),
              ),
              if (role == UserRole.admin) ...[
                _TelegramTile(
                  iconBg: const Color(0xFFFF3B30),
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Staff & Admin Moderation CMS',
                  trailingText: 'Monitor >',
                  isDark: isDark,
                  onTap: () => context.push('/admin/moderation'),
                ),
              ],
              _TelegramTile(
                iconBg: const Color(0xFF5AC8FA),
                icon: Icons.brightness_6_rounded,
                title: 'Appearance',
                trailingText: 'Auto >',
                isDark: isDark,
                onTap: () => context.push('/profile/appearance'),
              ),
              _TelegramTile(
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

          // ── Group 4: Account Tier & Platform Extensions ──────────────────
          _TelegramCardGroup(
            cardBg: cardBg,
            dividerColor: dividerColor,
            children: [
              _TelegramTile(
                iconBg: const Color(0xFFFFCC00),
                icon: Icons.verified_rounded,
                title: 'KYC & Verification',
                isDark: isDark,
                onTap: () => context.push('/kyc'),
              ),
              _TelegramTile(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.workspace_premium_rounded,
                title: 'Verification Badge',
                isDark: isDark,
                onTap: () => context.push('/verification-badge'),
              ),
              if (Permissions.roleHas(role, 'role.upgrade.apply'))
                _TelegramTile(
                  iconBg: const Color(0xFF007AFF),
                  icon: Icons.card_giftcard_rounded,
                  title: 'Gifts Catalogue',
                  isDark: isDark,
                  onTap: () => context.push('/gifts'),
                ),
              if (Permissions.roleHas(role, 'role.upgrade.apply'))
                _TelegramTile(
                  iconBg: const Color(0xFF34C759),
                  icon: Icons.upgrade_rounded,
                  title: 'Upgrade Account',
                  isDark: isDark,
                  onTap: () => context.push('/upgrade-account'),
                ),
              if (Permissions.roleHas(role, 'ai_onboarding.access'))
                _TelegramTile(
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
          _TelegramCardGroup(
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

  void _showRoleLockedDialog(BuildContext context, String requiredRoleTitle, String roleDescription, String targetRole) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFFFF9500), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                '$requiredRoleTitle Locked',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                roleDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/upgrade-account');
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                  label: Text('Apply to Become a $targetRole', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  void _showAccountSwitcherSheet(BuildContext context, bool isDark, UserRole role) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch Profile Mode',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Switch active profile to access specific tools & escrow',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              _accountModeTile(
                ctx,
                'Member Profile',
                'Personal chatting & social feed',
                Icons.person_rounded,
                const Color(0xFF007AFF),
                true,
                isDark,
              ),
              const SizedBox(height: 10),
              _accountModeTile(
                ctx,
                'Vendor Store Mode',
                'Products, store inventory & escrow orders',
                Icons.storefront_rounded,
                const Color(0xFF5856D6),
                role == UserRole.vendor,
                isDark,
                isLocked: role != UserRole.vendor && role != UserRole.admin,
                targetRole: 'Vendor',
                lockDescription: 'Vendor Store Mode is for Verified Vendors. Apply to open your store and receive escrow orders.',
              ),
              const SizedBox(height: 10),
              _accountModeTile(
                ctx,
                'Creator Hub Mode',
                'Brand deals, monetization & escrow payouts',
                Icons.campaign_rounded,
                const Color(0xFFFF9500),
                role == UserRole.creator,
                isDark,
                isLocked: role != UserRole.creator && role != UserRole.admin,
                targetRole: 'Creator',
                lockDescription: 'Creator Hub Mode is for Verified Creators. Apply to accept brand deals and receive locked escrow payouts.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountModeTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isSelected,
    bool isDark, {
    bool isLocked = false,
    String targetRole = '',
    String lockDescription = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: const Color(0xFF007AFF), width: 1.5) : null,
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          if (isLocked) {
            _showRoleLockedDialog(context, title, lockDescription, targetRole);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to $title')),
            );
          }
        },
        trailing: isLocked
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('APPLY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              )
            : (isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _profileStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TelegramCardGroup extends StatelessWidget {
  final Color cardBg;
  final Color dividerColor;
  final List<Widget> children;

  const _TelegramCardGroup({
    required this.cardBg,
    required this.dividerColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            color: dividerColor,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: items),
    );
  }
}

class _TelegramTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String? badgeText;
  final Color? badgeColor;
  final String? trailingText;
  final bool isDark;
  final VoidCallback onTap;

  const _TelegramTile({
    required this.iconBg,
    required this.icon,
    required this.title,
    this.badgeText,
    this.badgeColor,
    this.trailingText,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _CreatorMediaKitCard extends ConsumerWidget {
  final Color cardBg;
  final bool isDark;

  const _CreatorMediaKitCard({required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialState = ref.watch(socialAccountProvider);
    final followState = ref.watch(followProvider);
    final walletState = ref.watch(walletProvider);

    final verifiedAudience = socialState.summary?.combinedFollowers ?? followState.getFollowersCount(1);
    final linkedPlatformsCount = socialState.accounts.length;
    final creatorEarnings = walletState.creatorBalance;

    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF9500), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Creator Media Kit & Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary)),
                    Text('Live verified audience intelligence', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('REAL-TIME', style: TextStyle(color: Color(0xFFFF9500), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Verified Audience', '$verifiedAudience', textPrimary, textSecondary),
              _statItem('Linked Channels', '$linkedPlatformsCount', textPrimary, textSecondary),
              _statItem('Creator Earnings', '\$${creatorEarnings.toStringAsFixed(0)}', textPrimary, textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9500),
                    side: const BorderSide(color: Color(0xFFFF9500)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'https://murihspace.com/creator/mediakit'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Public Creator Media Kit link copied!')),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Export Media Kit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.push('/brand-deals'),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('Brand Deals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color textPrimary, Color? textSecondary) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
      ],
    );
  }
}

class _VendorStoreSummaryCard extends ConsumerWidget {
  final Color cardBg;
  final bool isDark;

  const _VendorStoreSummaryCard({required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF5856D6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vendor Store & Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary)),
                    Text('Escrow locked order & store analytics', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('VERIFIED STORE', style: TextStyle(color: Color(0xFF34C759), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Escrow Locked', '\$${walletState.businessEscrowBalance.toStringAsFixed(0)}', textPrimary, textSecondary),
              _statItem('Active Deals', '${walletState.escrowDeals.length}', textPrimary, textSecondary),
              _statItem('Vendor Rating', '4.9 ⭐', textPrimary, textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5856D6),
                    side: const BorderSide(color: Color(0xFF5856D6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.push('/wallet'),
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: const Text('Escrow Deals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5856D6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.push('/marketplace'),
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: const Text('Vendor Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color textPrimary, Color? textSecondary) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
      ],
    );
  }
}

