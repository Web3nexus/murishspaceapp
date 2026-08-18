import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import 'post_composer_sheet.dart';
import 'post_report_dialog.dart';

/// Discover tab — ranked feed (For You / Following) with post engagement.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final searchBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFF3F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Discover',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Telegram Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search topics, creators, public channels…',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Segmented TabBar
              TabBar(
                controller: _tab,
                labelColor: const Color(0xFF007AFF),
                unselectedLabelColor: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                indicatorColor: const Color(0xFF007AFF),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [Tab(text: 'For You'), Tab(text: 'Following')],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        onPressed: () => _compose(),
        child: const Icon(Icons.edit_outlined),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FeedList(feedType: 'home'),
          _FeedList(feedType: 'following'),
        ],
      ),
    );
  }

  Future<void> _compose() async {
    final post = await showPostComposer(context);
    if (post != null) {
      ref.read(postsProvider(const PostsSource.feed('home')).notifier).prepend(post);
    }
  }
}

class _FeedList extends ConsumerWidget {
  final String feedType;

  const _FeedList({required this.feedType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = PostsSource.feed(feedType);
    final state = ref.watch(postsProvider(source));
    final myId = ref.watch(authProvider).user?.id ?? 0;
    final notifier = ref.read(postsProvider(source).notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: _body(context, state, myId, notifier),
    );
  }

  Widget _body(BuildContext context, PostsState state, int myId, PostsNotifier notifier) {
    if (state.loading && state.posts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading feed…');
    }
    if (state.error != null && state.posts.isEmpty) {
      return ErrorStateWidget(title: 'Could not load feed', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.posts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.explore_outlined,
        title: 'Nothing here yet',
        description: 'Follow people and join communities to build your feed.',
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
          myId: myId,
          onLike: () => notifier.toggleLike(post, myId: myId),
          onSave: () => notifier.toggleSave(post),
          onCommentTap: () => showPostComments(
            context,
            post: post,
            myId: myId,
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
