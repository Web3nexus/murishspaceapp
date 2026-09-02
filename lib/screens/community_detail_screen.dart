import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/community_manage_sheet.dart';
import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import 'post_composer_sheet.dart';
import 'post_report_dialog.dart';

/// Community home: header + join/leave + Feed / Chats / Members tabs.
class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String slug;

  const CommunityDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncTabCount(int length) {
    if (_tabController.length == length) return;
    final index = _tabController.index.clamp(0, length - 1);
    _tabController.dispose();
    _tabController = TabController(length: length, vsync: this, initialIndex: index);
  }

  Future<void> _openChat(int communityId) async {
    final conversation =
        await ref.read(conversationsProvider.notifier).openCommunityChat(communityId);
    if (conversation == null || !mounted) return;
    context.push('/app/conversation/${conversation.id}');
  }

  Future<void> _compose(Community community) async {
    final post = await showPostComposer(context, initialCommunityId: community.id);
    if (post != null) {
      ref.read(postsProvider(PostsSource.community(community.id)).notifier).prepend(post);
    }
  }

  void _shareCommunity(Community community) {
    final link = 'https://murihspace.com/app/communities/${community.slug}';
    Clipboard.setData(ClipboardData(text: link));
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: Color(0xFF007AFF)),
                  const SizedBox(width: 10),
                  Text('Share ${community.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Anyone with this link can view the community and join.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        link,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Copied!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(communityDetailProvider(widget.slug));
    final community = detail.community;
    final membership = detail.membership;
    final myId = ref.watch(authProvider).user?.id;
    final isCreator = community?.creator?.id == myId;

    return Scaffold(
      appBar: AppBar(
        title: Text(community?.name ?? 'Community'),
        actions: [
          if (community != null) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Community',
              onPressed: () => _shareCommunity(community),
            ),
            if (isCreator)
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Manage Community',
                onPressed: () => CommunityManageSheet.show(context, community),
              ),
          ],
        ],
      ),
      body: switch (detail) {
        _ when detail.loading && community == null =>
          const LoadingStateWidget(message: 'Loading community…'),
        _ when detail.error != null && community == null =>
          ErrorStateWidget(title: 'Could not load community', description: detail.error!, onRetry: () => ref.read(communityDetailProvider(widget.slug).notifier).refresh()),
        _ => _buildContent(community!, membership, isCreator),
      },
    );
  }

  Widget _buildContent(Community community, MembershipStatus? membership, bool isCreator) {
    final isMember = membership?.isMember ?? false;
    final tabCount = isCreator ? 4 : 3;
    _syncTabCount(tabCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          _CommunityHeader(
            community: community,
            membership: membership,
            isCreator: isCreator,
            onJoin: () => _join(community),
            onLeave: () => _leave(community),
          ),
          Container(
            color: DesignTokens.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: DesignTokens.primaryDark,
              unselectedLabelColor: DesignTokens.textSecondary,
              indicatorColor: DesignTokens.primary,
              tabs: [
                const Tab(text: 'Feed'),
                const Tab(text: 'Chats'),
                const Tab(text: 'Members'),
                if (isCreator) const Tab(text: 'Requests'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FeedTab(
                  community: community,
                  isMember: isMember,
                  onCompose: () => _compose(community),
                ),
                _ChatsTab(
                  community: community,
                  isMember: isMember,
                  onOpenChat: () => _openChat(community.id),
                ),
                _MembersTab(communityId: community.id),
                if (isCreator) _RequestsTab(communityId: community.id),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _join(Community community) async {
    final isPaid = community.pricingType == 'paid' && (community.priceAmount ?? 0) > 0;
    if (isPaid) {
      final coins = (community.priceAmount ?? 50).toInt();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Subscribe to Community'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Joining ${community.name} requires an access fee of:'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFF9500), size: 24),
                  const SizedBox(width: 8),
                  Text('$coins Coins', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFF9500))),
                ],
              ),
              const SizedBox(height: 10),
              const Text('The coins will be deducted from your wallet balance.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Subscribe'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final notifier = ref.read(communityDetailProvider(widget.slug).notifier);
    final ok = await notifier.join();
    if (!mounted) return;
    if (ok) {
      final membership = ref.read(communityDetailProvider(widget.slug)).membership;
      final message = membership?.isPending == true
          ? 'Join request submitted.'
          : (isPaid ? 'Subscribed to ${community.name}!' : 'Joined ${community.name}.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      ref.read(myCommunitiesProvider.notifier).refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPaid ? 'Insufficient coin balance or error subscribing.' : 'Could not join this community.'),
          action: isPaid
              ? SnackBarAction(
                  label: 'Get Coins',
                  onPressed: () => context.push('/wallet'),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _leave(Community community) async {
    final notifier = ref.read(communityDetailProvider(widget.slug).notifier);
    final ok = await notifier.leave();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left the community.')),
      );
      ref.read(myCommunitiesProvider.notifier).remove(community.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave this community.')),
      );
    }
  }
}

class _CommunityHeader extends ConsumerWidget {
  final Community community;
  final MembershipStatus? membership;
  final bool isCreator;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  const _CommunityHeader({
    required this.community,
    this.membership,
    required this.isCreator,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMember = membership?.isMember ?? false;
    final isPending = membership?.isPending ?? false;
    final isPaid = community.pricingType == 'paid' && (community.priceAmount ?? 0) > 0;
    final coinPrice = (community.priceAmount ?? 50).toInt();
    final coverUrl = community.coverUrl;
    final logoUrl = community.logoUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Container
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: coverUrl != null && coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
              // Creator Edit & Manage Button
              if (isCreator)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => CommunityManageSheet.show(context, community),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.settings_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Manage Community', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              // Circular Profile Pic / Logo Avatar Overlap
              Positioned(
                bottom: -28,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFF007AFF),
                    backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                    child: logoUrl == null || logoUrl.isEmpty
                        ? Text(
                            community.initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Community Info & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${community.membersCount} members · ${community.visibility.toUpperCase()}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                              ),
                              if (isPaid) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on_rounded, size: 11, color: Color(0xFFFF9500)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$coinPrice Coins',
                                        style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isMember)
                      OutlinedButton(
                        onPressed: onLeave,
                        child: const Text('Leave'),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaid ? const Color(0xFFFF9500) : const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: isPending ? null : onJoin,
                        child: isPending
                            ? const Text('Pending')
                            : (isPaid
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('Subscribe ($coinPrice)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                : const Text('Join Community', style: TextStyle(fontWeight: FontWeight.bold))),
                      ),
                  ],
                ),
                if (community.description != null && community.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      community.description!,
                      style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  final Community community;
  final bool isMember;
  final VoidCallback onCompose;

  const _FeedTab({
    required this.community,
    required this.isMember,
    required this.onCompose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = PostsSource.community(community.id);
    final state = ref.watch(postsProvider(source));
    final myId = ref.watch(authProvider).user?.id;
    final notifier = ref.read(postsProvider(source).notifier);

    return Scaffold(
      backgroundColor: DesignTokens.background,
      floatingActionButton: isMember
          ? FloatingActionButton(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
              onPressed: onCompose,
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _postsBody(context, ref, state, myId, notifier),
      ),
    );
  }

  Widget _postsBody(BuildContext context, WidgetRef ref, PostsState state, int? myId, PostsNotifier notifier) {
    if (state.loading && state.posts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading posts…');
    }
    if (state.error != null && state.posts.isEmpty) {
      return ErrorStateWidget(title: 'Could not load posts', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.posts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.article_outlined,
        title: 'No posts yet',
        description: 'Be the first to share something in this community.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: state.posts.length + (state.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= state.posts.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: state.loadingMore
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : TextButton(onPressed: () => notifier.loadMore(), child: const Text('Load more')),
            ),
          );
        }
        final post = state.posts[i];
        return PostCard(
          post: post,
          myId: myId ?? 0,
          onLike: () => notifier.toggleLike(post, myId: myId ?? 0),
          onSave: () => notifier.toggleSave(post),
          onCommentTap: () => showPostComments(
            context,
            post: post,
            myId: myId ?? 0,
            onAddComment: (content) => notifier.addComment(post, content),
          ),
          onShare: () async {
            await notifier.share(post);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post shared.')),
              );
            }
          },
          onReport: () async {
            final reason = await showPostReportDialog(context, post: post);
            if (reason == null) return;
            final ok = await notifier.report(post, reason);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Post reported. Thanks!' : 'Could not report this post.')),
              );
            }
          },
        );
      },
    );
  }
}

class _ChatsTab extends StatelessWidget {
  final Community community;
  final bool isMember;
  final VoidCallback onOpenChat;

  const _ChatsTab({
    required this.community,
    required this.isMember,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return const EmptyStateWidget(
        icon: Icons.chat_outlined,
        title: 'Members only',
        description: 'Join this community to access the group chat.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: DesignTokens.primarySoft,
            child: Icon(Icons.chat_outlined, color: DesignTokens.primaryDark),
          ),
          title: const Text('General chat', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${community.name} General'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenChat,
        ),
      ],
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final int communityId;

  const _MembersTab({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityMembersProvider(communityId));
    if (state.loading && state.members.isEmpty) {
      return const LoadingStateWidget(message: 'Loading members…');
    }
    if (state.error != null && state.members.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load members',
        description: state.error!,
        onRetry: () => ref.read(communityMembersProvider(communityId).notifier).refresh(),
      );
    }
    if (state.members.isEmpty) {
      return const EmptyStateWidget(icon: Icons.people_outline, title: 'No members yet');
    }
    return ListView.separated(
      itemCount: state.members.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final member = state.members[i];
        final user = member.user;
        final avatarUrl = user?.avatarUrl;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: DesignTokens.primarySoft,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    (user?.name ?? '?').isEmpty ? '?' : (user!.name).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          title: Text(user?.name ?? 'MurihSpace user'),
          subtitle: member.role != 'member'
              ? Text(member.role, style: const TextStyle(color: DesignTokens.primaryDark))
              : null,
        );
      },
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  final int communityId;

  const _RequestsTab({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityRequestsProvider(communityId));
    final notifier = ref.read(communityRequestsProvider(communityId).notifier);

    if (state.loading && state.requests.isEmpty) {
      return const LoadingStateWidget(message: 'Loading requests…');
    }
    if (state.error != null && state.requests.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load requests',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }
    if (state.requests.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pending_actions_outlined,
        title: 'No pending requests',
        description: 'Join requests from users will appear here for approval.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.requests.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final request = state.requests[i];
          final user = request.user;
          final avatarUrl = user?.avatarUrl;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: DesignTokens.primarySoft,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      (user?.name ?? '?').isEmpty ? '?' : (user!.name).substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            title: Text(user?.name ?? 'MurihSpace user'),
            subtitle: const Text('Wants to join'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => notifier.approve(request),
                  icon: const Icon(Icons.check_circle_outline, color: DesignTokens.primary),
                  tooltip: 'Approve',
                ),
                IconButton(
                  onPressed: () => notifier.reject(request),
                  icon: const Icon(Icons.cancel_outlined, color: DesignTokens.danger),
                  tooltip: 'Reject',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
