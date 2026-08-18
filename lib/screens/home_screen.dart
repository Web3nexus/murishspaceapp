import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../components/ui_states.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/story_provider.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import 'post_composer_sheet.dart';
import 'post_report_dialog.dart';
import 'story_composer_sheet.dart';
import 'story_viewer_screen.dart';

/// FB/Instagram style Home Feed screen with MurihSpace Brand Logo & Messenger jump action.
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenMessages;

  const HomeScreen({super.key, required this.onOpenMessages});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: BrandLogo(
          role: user?.role,
          height: 30,
          isDark: isDark,
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends'),
            icon: Icon(
              Icons.people_outline_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            tooltip: 'Friends & Requests',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: widget.onOpenMessages,
              icon: const BrandFavicon(
                size: 24,
              ),
              tooltip: 'Messenger Chats',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(postsProvider(const PostsSource.feed('home')).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // What's on your mind composer bar (Facebook style: post creation block first)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF007AFF),
                        child: Text(
                          (user?.name ?? 'M')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _compose,
                          child: Text(
                            "What's on your mind, ${user != null ? user.name.split(' ').first : 'there'}?",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _compose,
                        icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF34C759), size: 22),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // Stories Row (Facebook style: stories row under writing post block)
              const _StoriesRow(),
              const Divider(height: 1),

              // Home Feed Posts
              const _HomeFeedPosts(),
            ],
          ),
        ),
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

class _StoriesRow extends ConsumerWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storyState = ref.watch(storyProvider);
    final user = ref.watch(authProvider).user;
    final groups = storyState.groups;

    return Container(
      height: 105,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        itemBuilder: (ctx, i) {
          final group = groups[i];

          // -----------------------------------------------------------------
          // ITEM 0: "Add Story" / "Your Story" Bubble
          // -----------------------------------------------------------------
          if (group.isMyStory) {
            final hasStories = group.stories.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () {
                  if (hasStories) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerScreen(group: group),
                      ),
                    );
                  } else {
                    showStoryComposerSheet(context);
                  }
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasStories
                                ? const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF2D55)],
                                  )
                                : null,
                            color: hasStories ? null : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6)),
                          ),
                          child: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            child: Text(
                              (user?.name ?? 'M')[0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        // Plus (+) Badge Icon
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => showStoryComposerSheet(context),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF18191A) : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasStories ? 'Your Story' : 'Add Story',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // -----------------------------------------------------------------
          // ITEM > 0: Followed Friends & Joined Communities Story Bubbles
          // -----------------------------------------------------------------
          final hasUnseen = group.hasUnseen;

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(group: group),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasUnseen
                          ? const LinearGradient(
                              colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF2D55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: hasUnseen
                          ? null
                          : Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              width: 1.5,
                            ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      backgroundImage: group.userAvatar != null ? NetworkImage(group.userAvatar!) : null,
                      child: group.userAvatar == null
                          ? Text(
                              group.userName[0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      group.userName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasUnseen ? FontWeight.bold : FontWeight.w600,
                        color: hasUnseen
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeFeedPosts extends ConsumerWidget {
  const _HomeFeedPosts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = const PostsSource.feed('home');
    final state = ref.watch(postsProvider(source));
    final myId = ref.watch(authProvider).user?.id ?? 0;
    final notifier = ref.read(postsProvider(source).notifier);

    if (state.loading && state.posts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading feed…');
    }
    if (state.error != null && state.posts.isEmpty) {
      return ErrorStateWidget(title: 'Could not load feed', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.posts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.explore_outlined,
        title: 'Nothing in feed yet',
        description: 'Follow people and join communities to build your feed.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.posts.length,
      itemBuilder: (_, i) {
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
