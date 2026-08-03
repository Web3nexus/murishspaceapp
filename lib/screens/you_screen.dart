import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';

/// "You" tab — profile summary, account entries, and logout.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.navy,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: DesignTokens.primary,
                  child: Text(
                    _initials(user?.name ?? '?'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'MurihSpace user',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user?.username ?? 'username'}',
                        style: const TextStyle(
                          color: DesignTokens.sidebarForeground,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: DesignTokens.sidebarAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          (user?.role ?? UserRole.member).label,
                          style: const TextStyle(
                            color: DesignTokens.sidebarPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Account'),
          _EntryTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Message alerts and activity',
            onTap: () => context.push('/app/notifications'),
          ),
          _EntryTile(
            icon: Icons.bookmark_outline,
            title: 'Saved Posts',
            subtitle: 'Posts you have bookmarked',
            onTap: () => context.push('/app/saved'),
          ),
          _EntryTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet',
            subtitle: 'Coins, transfers, escrow',
            onTap: () => context.push('/wallet'),
          ),
          _EntryTile(
            icon: Icons.card_giftcard,
            title: 'Gifts',
            subtitle: 'Gift catalogue and history',
            onTap: () => context.push('/gifts'),
          ),
          _EntryTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Name, username, bio',
            onTap: () => context.push('/profile'),
          ),
          _EntryTile(
            icon: Icons.verified_user_outlined,
            title: 'KYC & Verification',
            subtitle: 'Identity and badge status',
            onTap: () => context.push('/kyc'),
          ),
          _EntryTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Coming in a later phase',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon')),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Session'),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: DesignTokens.danger,
              side: const BorderSide(color: DesignTokens.danger),
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: DesignTokens.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DesignTokens.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: DesignTokens.primaryDark),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: DesignTokens.textSecondary),
      ),
    );
  }
}
