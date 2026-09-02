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

import '../components/go_live_setup_dialog.dart';
import '../components/send_gift_dialog.dart';

/// Community home: header + join/leave + Feed / Courses / Chats / Members tabs.
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
    _tabController = TabController(length: 4, vsync: this);
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

  void _openCommunityGifting(Community community) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        recipientId: community.creator?.id ?? community.userId ?? 1,
        recipientName: community.name,
        onGiftSent: (gift, amount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF9500),
              content: Text('Sent ${gift.name} (+$amount Coins) to ${community.name}!'),
            ),
          );
        },
      ),
    );
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
              icon: const Icon(Icons.videocam_rounded, color: Color(0xFFFF3B30)),
              tooltip: 'Go Live / Host Meeting',
              onPressed: () => GoLiveSetupDialog.show(context, community: community),
            ),
            IconButton(
              icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
              tooltip: 'Gift Community',
              onPressed: () => _openCommunityGifting(community),
            ),
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
    final tabCount = isCreator ? 5 : 4;
    _syncTabCount(tabCount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF8E8E93);

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
            color: cardBg,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF007AFF),
              unselectedLabelColor: textSecondary,
              indicatorColor: const Color(0xFF007AFF),
              tabs: [
                const Tab(text: 'Feed'),
                const Tab(text: 'Courses & Goods'),
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
                _CoursesAndGoodsTab(
                  community: community,
                  isMember: isMember,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    if (!isMember) {
      return const EmptyStateWidget(
        icon: Icons.chat_outlined,
        title: 'Members only',
        description: 'Join this community to access the group chat.',
      );
    }
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                child: const Icon(Icons.chat_outlined, color: Color(0xFF007AFF)),
              ),
              title: Text('General chat', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
              subtitle: Text('${community.name} Community Discussion', style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenChat,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final int communityId;

  const _MembersTab({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

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
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: state.members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final member = state.members[i];
          final user = member.user;
          final avatarUrl = user?.avatarUrl;
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        (user?.name ?? '?').isEmpty ? '?' : (user!.name).substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              title: Text(user?.name ?? 'MurihSpace user', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
              subtitle: member.role != 'member'
                  ? Text(member.role.toUpperCase(), style: const TextStyle(color: Color(0xFF007AFF), fontSize: 11, fontWeight: FontWeight.w800))
                  : Text('@${user?.username ?? 'user'}', style: TextStyle(color: textSecondary, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  final int communityId;

  const _RequestsTab({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

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
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final request = state.requests[i];
            final user = request.user;
            final avatarUrl = user?.avatarUrl;
            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          (user?.name ?? '?').isEmpty ? '?' : (user!.name).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                title: Text(user?.name ?? 'MurihSpace user', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                subtitle: Text('Requested to join', style: TextStyle(color: textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => notifier.approve(request),
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      onPressed: () => notifier.reject(request),
                      icon: const Icon(Icons.cancel_rounded, color: Color(0xFFFF3B30)),
                      tooltip: 'Reject',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoursesAndGoodsTab extends ConsumerStatefulWidget {
  final Community community;
  final bool isMember;

  const _CoursesAndGoodsTab({required this.community, required this.isMember});

  @override
  ConsumerState<_CoursesAndGoodsTab> createState() => _CoursesAndGoodsTabState();
}

class _CoursesAndGoodsTabState extends ConsumerState<_CoursesAndGoodsTab> {
  List<Map<String, dynamic>> _digitalGoods = [
    {
      'id': 1,
      'type': 'course',
      'title': 'Complete Creator Mastery & Monetization',
      'price': '₦25,000 / \$30',
      'is_public': true,
      'is_exclusive': false,
      'lessons_count': 18,
      'image_url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500',
    },
    {
      'id': 2,
      'type': 'digital_product',
      'title': 'VIP Member Templates & Design Kit',
      'price': 'FREE for Members',
      'is_public': false,
      'is_exclusive': true,
      'file_type': 'ZIP Archive (48MB)',
      'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500',
    },
    {
      'id': 3,
      'type': 'course',
      'title': 'Advanced Community Growth Blueprint',
      'price': '50 Coins',
      'is_public': true,
      'is_exclusive': false,
      'lessons_count': 12,
      'image_url': 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=500',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community Courses & Digital Goods',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_digitalGoods.length} Items',
                  style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._digitalGoods.map((item) {
            final isCourse = item['type'] == 'course';
            final isExclusive = item['is_exclusive'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(
                      item['image_url'] as String,
                      width: double.infinity,
                      height: 130,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCourse
                                    ? const Color(0xFF007AFF).withOpacity(0.15)
                                    : const Color(0xFF5856D6).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCourse ? 'COURSE' : 'DIGITAL ASSET',
                                style: TextStyle(
                                  color: isCourse ? const Color(0xFF007AFF) : const Color(0xFF5856D6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExclusive
                                    ? const Color(0xFFFF9500).withOpacity(0.15)
                                    : const Color(0xFF34C759).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExclusive ? 'MEMBERS ONLY' : 'PUBLIC MARKETPLACE',
                                style: TextStyle(
                                  color: isExclusive ? const Color(0xFFFF9500) : const Color(0xFF34C759),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title'] as String,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCourse ? '${item['lessons_count']} interactive lessons' : '${item['file_type']}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['price'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF34C759)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Accessing ${item['title']}!')),
                                );
                              },
                              child: Text(
                                isExclusive && !widget.isMember ? 'Join to Access' : (isCourse ? 'Start Learning' : 'Download Asset'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
