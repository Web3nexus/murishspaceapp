import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';

/// Full-screen followers hub showing a user's Followers, Following and Friends
/// in three tabs, with search and 1-tap follow actions.
class FollowersScreen extends ConsumerStatefulWidget {
  final int? userId;

  const FollowersScreen({super.key, this.userId});

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authUser = ref.read(authProvider).user;
    final targetId = widget.userId ?? authUser?.id ?? 0;
    if (targetId > 0) {
      final notifier = ref.read(followProvider.notifier);
      await Future.wait([
        notifier.fetchFollowers(targetId),
        notifier.fetchFollowing(targetId),
      ]);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openProfile(int id, String name, String username) {
    context.push(
      '/profile/user/$id?name=${Uri.encodeComponent(name)}&username=${Uri.encodeComponent(username)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);
    final authUser = ref.watch(authProvider).user;
    final targetId = widget.userId ?? authUser?.id ?? 0;
    final friends = ref.watch(friendsProvider).friends;

    final followers = followNotifier.getFollowersList(targetId);
    final following = followNotifier.getFollowingList(targetId);

    bool match(String name, String username) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return name.toLowerCase().contains(q) ||
          username.toLowerCase().contains(q);
    }

    final filteredFollowers = followers
        .where((u) => match(u.name, u.username))
        .toList();
    final filteredFollowing = following
        .where((u) => match(u.name, u.username))
        .toList();
    final filteredFriends = friends
        .where((u) => match(u.name, u.username))
        .toList();

    final followersTotal = followState.getFollowersCount(targetId);
    final followingTotal = followState.getFollowingCount(targetId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Followers',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Search people...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tab,
                labelColor: DesignTokens.primary,
                unselectedLabelColor: textSecondary,
                indicatorColor: DesignTokens.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    text:
                        'Followers (${followersTotal > 0 ? followersTotal : followers.length})',
                  ),
                  Tab(
                    text:
                        'Following (${followingTotal > 0 ? followingTotal : following.length})',
                  ),
                  Tab(text: 'Friends (${friends.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : TabBarView(
              controller: _tab,
              children: [
                _buildFollowList(
                  items: filteredFollowers,
                  emptyText: 'No followers yet',
                  emptyIcon: Icons.people_outline_rounded,
                  isFollowers: true,
                  textSecondary: textSecondary,
                  authUserId: authUser?.id ?? 0,
                  followState: followState,
                  followNotifier: followNotifier,
                ),
                _buildFollowList(
                  items: filteredFollowing,
                  emptyText: 'Not following anyone yet',
                  emptyIcon: Icons.person_search_rounded,
                  isFollowers: false,
                  textSecondary: textSecondary,
                  authUserId: authUser?.id ?? 0,
                  followState: followState,
                  followNotifier: followNotifier,
                ),
                filteredFriends.isEmpty
                    ? _buildEmptyState(
                        'No friends yet',
                        Icons.group_rounded,
                        textSecondary,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredFriends.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (ctx, i) {
                          final user = filteredFriends[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: DesignTokens.primary,
                              backgroundImage:
                                  user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child:
                                  user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 26,
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '@${user.username}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            onTap: () =>
                                _openProfile(user.id, user.name, user.username),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  Widget _buildFollowList({
    required List<UserFollowSummary> items,
    required String emptyText,
    required IconData emptyIcon,
    required bool isFollowers,
    required Color? textSecondary,
    required int authUserId,
    required FollowState followState,
    required FollowNotifier followNotifier,
  }) {
    if (items.isEmpty)
      return _buildEmptyState(emptyText, emptyIcon, textSecondary);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final user = items[i];
        final isFollowing =
            followState.isFollowing(user.userId) || user.isFollowing;
        final isSelf = authUserId == user.userId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
            backgroundImage: user.avatarUrl.isNotEmpty
                ? NetworkImage(user.avatarUrl)
                : null,
            child: user.avatarUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    color: DesignTokens.primary,
                    size: 22,
                  )
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isSelf
                        ? DesignTokens.primary
                        : (Theme.of(ctx).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  color: DesignTokens.primary,
                  size: 16,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '@${user.username}${user.bio.isNotEmpty ? ' · ${user.bio}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          trailing: isSelf
              ? null
              : SizedBox(
                  height: 34,
                  child: isFollowing
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: BorderSide(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () =>
                              followNotifier.toggleFollow(user.userId),
                          child: const Text(
                            'Following',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () =>
                              followNotifier.toggleFollow(user.userId),
                          child: const Text(
                            'Follow',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
          onTap: () => _openProfile(user.userId, user.name, user.username),
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon, Color? color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
