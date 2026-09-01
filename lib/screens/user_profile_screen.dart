import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../components/send_gift_dialog.dart';
import '../providers/follow_provider.dart';

/// Public User & Friend Profile Screen with Gifting, Direct Messaging, & Follow CTAs.
class UserProfileScreen extends ConsumerStatefulWidget {
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
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followProvider.notifier).fetchFollowStatus(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final isFollowing = followState.isFollowing(widget.userId);
    final followersCount = followState.getFollowersCount(widget.userId);
    final followingCount = followState.getFollowingCount(widget.userId);
    final postsCount = followState.getPostsCount(widget.userId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '@${widget.username}',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
            tooltip: 'Send Gift',
            onPressed: () => SendGiftDialog.show(
              context,
              recipientName: widget.name,
              recipientAvatar: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
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
                        backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                        child: widget.avatarUrl.isEmpty
                            ? Text(
                                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.name,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.username}',
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
                      widget.roleLabel.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.bio,
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
                        () => FollowersListDialog.show(context, title: '${widget.name}\'s Followers', isFollowersList: true, userId: widget.userId),
                      ),
                      _statCol(
                        'Following',
                        '$followingCount',
                        textPrimary,
                        textSecondary,
                        () => FollowersListDialog.show(context, title: '${widget.name}\'s Following', isFollowersList: false, userId: widget.userId),
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
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => followNotifier.toggleFollow(widget.userId),
                          icon: Icon(
                            isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                            foregroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => context.push('/messages'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Activity & Highlights Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Highlights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hub_rounded, color: Color(0xFF007AFF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Creator & Verified Member',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active contributor to Web3, Creator Economy & Vendor communities on MurihSpace.',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color textPrimary, Color? textSecondary, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
