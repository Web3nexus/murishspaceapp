import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(communityDetailProvider(widget.slug));
    final community = detail.community;
    final membership = detail.membership;
    final myId = ref.watch(authProvider).user?.id;
    final isCreator = community?.creator?.id == myId;

    return Scaffold(
      appBar: AppBar(title: Text(community?.name ?? 'Community')),
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
    final notifier = ref.read(communityDetailProvider(widget.slug).notifier);
    final ok = await notifier.join();
    if (!mounted) return;
    if (ok) {
      final membership = ref.read(communityDetailProvider(widget.slug)).membership;
      final message = membership?.isPending == true
          ? 'Join request submitted.'
          : 'Joined ${community.name}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      ref.read(myCommunitiesProvider.notifier).refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join this community.')),
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

class _CommunityHeader extends StatelessWidget {
  final Community community;
  final MembershipStatus? membership;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  const _CommunityHeader({
    required this.community,
    this.membership,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isMember = membership?.isMember ?? false;
    final isPending = membership?.isPending ?? false;
    final coverUrl = community.coverUrl;

    return Container(
      color: DesignTokens.surface,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl != null && coverUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 120,
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: DesignTokens.primarySoft,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Logo(community: community, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: DesignTokens.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${community.membersCount} members',
                        style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                      ),
                      if (community.description != null && community.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          community.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: DesignTokens.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                if (isMember)
                  OutlinedButton(
                    onPressed: onLeave,
                    child: const Text('Leave'),
                  )
                else if (isPending)
                  const SizedBox(
                    height: 36,
                    child: FilledButton.tonal(onPressed: null, child: Text('Pending')),
                  )
                else
                  FilledButton(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.primary),
                    child: const Text('Join community'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final Community community;
  final double size;

  const _Logo({required this.community, required this.size});

  @override
  Widget build(BuildContext context) {
    final logoUrl = community.logoUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: DesignTokens.primarySoft,
      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
      child: logoUrl == null || logoUrl.isEmpty
          ? Text(
              community.initials,
              style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700, fontSize: 20),
            )
          : null,
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
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
