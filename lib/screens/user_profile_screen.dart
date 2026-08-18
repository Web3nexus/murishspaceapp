import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/followers_list_dialog.dart';
import '../components/send_gift_dialog.dart';
import '../providers/follow_provider.dart';
import '../providers/social_account_provider.dart';

/// Public User & Friend Profile Screen with Gifting, Direct Messaging, & Follow CTAs.
class UserProfileScreen extends ConsumerWidget {
  final int userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;
  final String roleLabel;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl = '',
    this.bio = 'Digital Creator & Community Contributor ✨',
    this.roleLabel = 'Creator',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);
    final socialState = ref.watch(socialAccountProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final isFollowing = followState.isFollowing(userId);
    final followersCount = followState.getFollowersCount(userId);
    final followingCount = followState.getFollowingCount(userId);
    final postsCount = followState.getPostsCount(userId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '@$username',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
            tooltip: 'Send Gift',
            onPressed: () => SendGiftDialog.show(
              context,
              recipientName: name,
              recipientAvatar: avatarUrl.isNotEmpty ? avatarUrl : null,
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar with Gradient Ring
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: cardBg,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                ),
                const SizedBox(height: 8),

                // Role Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleLabel.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                ),
                const SizedBox(height: 18),

                // Interactive Stats Row
                Row(
                  mainAxisAlignment: Main.spaceAround,
                  children: [
                    _statCol('Posts', '$postsCount', textPrimary, textSecondary, () {}),
                    _statCol(
                      'Followers',
                      '$followersCount',
                      textPrimary,
                      textSecondary,
                      () => FollowersListDialog.show(context, title: '$name\'s Followers', isFollowersList: true),
                    ),
                    _statCol(
                      'Following',
                      '$followingCount',
                      textPrimary,
                      textSecondary,
                      () => FollowersListDialog.show(context, title: '$name\'s Following', isFollowersList: false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Primary Action CTAs
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)) : const Color(0xFF007AFF),
                          foregroundColor: isFollowing ? textPrimary : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => followNotifier.toggleFollow(userId),
                        icon: Icon(isFollowing ? Icons.check_rounded : Icons.person_add_rounded, size: 18),
                        label: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          side: const BorderSide(color: Color(0xFF007AFF)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => context.push('/app/chats'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text('Message', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.15)),
                      icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
                      onPressed: () => SendGiftDialog.show(
                        context,
                        recipientName: name,
                        recipientAvatar: avatarUrl.isNotEmpty ? avatarUrl : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Connected Social Accounts Section
          Text('CONNECTED CHANNELS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _platformBadge('Instagram', '@$username', const Color(0xFFE1306C)),
                _platformBadge('TikTok', '@$username', Colors.black),
                _platformBadge('YouTube', '$name TV', const Color(0xFFFF0000)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val, Color textPrimary, Color? textSecondary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
          Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _platformBadge(String label, String handle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$label: $handle', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
