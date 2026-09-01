import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/language_provider.dart';
import '../providers/social_account_provider.dart';
import '../providers/wallet_provider.dart';

import '../models/community_models.dart';
import '../providers/community_provider.dart';
import 'post_card.dart';
import 'post_composer_sheet.dart';

/// Facebook/Instagram style Profile screen with banner, dynamic stats, friends grid & posts feed.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final followState = ref.watch(followProvider);
    final friendsState = ref.watch(friendsProvider);
    final user = auth.user;
    final role = user?.role ?? UserRole.member;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    final followersCount = user?.followersCount ?? followState.getFollowersCount(user?.id ?? 0);
    final followingCount = user?.followingCount ?? followState.getFollowingCount(user?.id ?? 0);
    final postsCount = user?.postsCount ?? followState.getPostsCount(user?.id ?? 0);
    final coinsCount = user?.coins ?? 0;

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
            onPressed: () => context.push('/settings'),
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            tooltip: 'Settings',
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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshProfile();
          await ref.read(friendsProvider.notifier).loadAll();
          if (user != null) {
            await ref.read(followProvider.notifier).fetchFollowStatus(user.id);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
          // ── Group 0: Header Profile Card with Banner ─────────────────────
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
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
                  // Cover Banner Header
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF9500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      image: user?.bannerUrl != null && user!.bannerUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(user.bannerUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Overlapping Avatar & Info Row
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              OnlineAvatarBadge(
                                isOnline: true,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cardBg,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    width: 64,
                                    height: 64,
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                user?.name ?? 'MurihSpace User',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 19,
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
                          Row(
                            children: [
                              Text(
                                '@${(user?.username != null && user!.username.isNotEmpty) ? user.username : (user?.name ?? 'user').toLowerCase().replaceAll(' ', '_')}',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const OnlineStatusBadge(isOnline: true, showLabel: true),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showAccountSwitcherSheet(context, ref, isDark, role),
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
                          if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              user.bio!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 12),
                  // Dynamic quick stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _profileStat('Posts', '$postsCount', isDark),
                      _profileStat(
                        'Followers',
                        '$followersCount',
                        isDark,
                        onTap: () => FollowersListDialog.show(context, title: 'Followers', isFollowersList: true, userId: user?.id),
                      ),
                      _profileStat(
                        'Following',
                        '$followingCount',
                        isDark,
                        onTap: () => FollowersListDialog.show(context, title: 'Following', isFollowersList: false, userId: user?.id),
                      ),
                      _profileStat(
                        'Coins',
                        '$coinsCount',
                        isDark,
                        onTap: () => context.push('/wallet'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Group 1: Friends Section (FB Style) ──────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Friends',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          friendsState.friends.isEmpty
                              ? 'No connections yet'
                              : '${friendsState.friends.length} connection${friendsState.friends.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/friends'),
                      child: const Text('See All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (friendsState.friends.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E).withOpacity(0.5) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_outline_rounded, color: Color(0xFF007AFF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Find & add friends',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black),
                              ),
                              Text(
                                'Sync contacts or search creators to connect.',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/friends'),
                          child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 105,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: friendsState.friends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final friend = friendsState.friends[i];
                        final name = friend.name;
                        final uname = friend.username;

                        return GestureDetector(
                          onTap: () => context.push('/profile/user/${friend.id}?name=$name&username=$uname'),
                          child: Container(
                            width: 84,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                                      ? NetworkImage(friend.avatarUrl!)
                                      : null,
                                  backgroundColor: const Color(0xFF007AFF),
                                  child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                                      ? Text(
                                          _initials(name),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Group 2: Your Posts Feed Section ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Posts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () => showPostComposer(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Consumer(
                  builder: (context, ref, _) {
                    final postsState = ref.watch(postsProvider(const PostsSource.feed('home')));
                    final myPosts = postsState.posts.where((p) => p.userId == user?.id || user == null).toList();

                    if (postsState.loading && myPosts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (myPosts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.feed_outlined, size: 40, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No posts created yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Share your thoughts, photos, or updates with your community.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: myPosts.take(5).map((post) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(post: post, myId: user?.id ?? 0),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                    final router = GoRouter.of(context);
                    Navigator.pop(ctx);
                    router.push('/upgrade-account');
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

  void _showAccountSwitcherSheet(BuildContext context, WidgetRef ref, bool isDark, UserRole role) {
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
                ref,
                'Member Profile',
                'Personal chatting & social feed',
                Icons.person_rounded,
                const Color(0xFF007AFF),
                role == UserRole.member,
                isDark,
                targetRole: 'member',
              ),
              const SizedBox(height: 10),
              _accountModeTile(
                ctx,
                ref,
                'Vendor Store Mode',
                'Products, store inventory & escrow orders',
                Icons.storefront_rounded,
                const Color(0xFF5856D6),
                role == UserRole.vendor,
                isDark,
                targetRole: 'vendor',
              ),
              const SizedBox(height: 10),
              _accountModeTile(
                ctx,
                ref,
                'Creator Hub Mode',
                'Brand deals, monetization & escrow payouts',
                Icons.campaign_rounded,
                const Color(0xFFFF9500),
                role == UserRole.creator,
                isDark,
                targetRole: 'creator',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountModeTile(
    BuildContext context,
    WidgetRef ref,
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
        onTap: () async {
          Navigator.pop(context);
          if (isLocked) {
            _showRoleLockedDialog(context, title, lockDescription, targetRole);
          } else {
            final targetEnum = switch (targetRole.toLowerCase()) {
              'creator' => UserRole.creator,
              'vendor' => UserRole.vendor,
              _ => UserRole.member,
            };
            await ref.read(authProvider.notifier).switchRole(targetEnum);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Switched active mode to $title')),
              );
            }
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

  Widget _profileStat(String label, String value, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCardGroup extends StatelessWidget {
  final Color cardBg;
  final Color dividerColor;
  final List<Widget> children;

  const _ProfileCardGroup({
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

class _ProfileTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String? badgeText;
  final Color? badgeColor;
  final String? trailingText;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileTile({
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

