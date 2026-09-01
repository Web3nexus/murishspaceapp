import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../components/send_gift_dialog.dart';
import '../providers/follow_provider.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
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
        padding: EdgeInsets.zero,
        children: [
          // Sleek Cover Banner Header
          Container(
            height: 110,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF9500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Avatar with Gradient Ring & Online Presence Badge
                  OnlineAvatarBadge(
                    isOnline: true,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: bg,
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 6),
                  const OnlineStatusBadge(isOnline: true, showLabel: true),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  const SizedBox(height: 24),

                  // Connected Social Channels Row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CONNECTED CHANNELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 0.8)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _platformBadge('Instagram', '@$username', const Color(0xFFE1306C)),
                      const SizedBox(width: 8),
                      _platformBadge('TikTok', '@$username', Colors.black),
                      const SizedBox(width: 8),
                      _platformBadge('YouTube', '$name TV', const Color(0xFFFF0000)),
                    ],
                  ),
                ],
              ),
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
