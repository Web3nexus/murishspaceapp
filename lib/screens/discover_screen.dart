import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/api_client.dart';
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
  Timer? _searchDebounce;
  bool _searching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _communityResults = [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searching = false;
        _userResults = [];
        _communityResults = [];
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _performSearch(q));
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _searchQuery = query;
      _searching = true;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/search',
        queryParameters: {'q': query, 'type': 'all', 'per_page': 20},
      );
      final payload = ApiClient.instance.unwrap(response);
      List<Map<String, dynamic>> users = [];
      List<Map<String, dynamic>> communities = [];

      if (payload is Map<String, dynamic>) {
        final rawResults = payload['results'];
        if (rawResults is Map<String, dynamic>) {
          if (rawResults['users'] is List) {
            users = (rawResults['users'] as List).whereType<Map<String, dynamic>>().toList();
          }
          if (rawResults['communities'] is List) {
            communities = (rawResults['communities'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
        if (users.isEmpty && payload['users'] is List) {
          users = (payload['users'] as List).whereType<Map<String, dynamic>>().toList();
        }
        if (communities.isEmpty && payload['communities'] is List) {
          communities = (payload['communities'] as List).whereType<Map<String, dynamic>>().toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _userResults = users;
        _communityResults = communities;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final searchBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFF3F6);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

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
            color: textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchQuery.isNotEmpty ? 52 : 100),
          child: Column(
            children: [
              // Search Input
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
                        color: const Color(0xFF8E8E93),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) => _performSearch(v.trim()),
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search people, creators, topics…',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_searchQuery.isEmpty) ...[
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
              ] else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      floatingActionButton: _searchQuery.isEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              onPressed: () => _compose(),
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      body: _searchQuery.isNotEmpty
          ? _buildSearchResults(isDark, cardBg, textPrimary, textSecondary)
          : TabBarView(
              controller: _tab,
              children: const [
                _FeedList(feedType: 'home'),
                _FeedList(feedType: 'following'),
              ],
            ),
    );
  }

  Widget _buildSearchResults(bool isDark, Color cardBg, Color textPrimary, Color? textSecondary) {
    if (_searching) {
      return const LoadingStateWidget(message: 'Searching creators and topics…');
    }

    if (_userResults.isEmpty && _communityResults.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'No results found',
        description: 'No users or channels matching "$_searchQuery". Try another keyword.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_userResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'PEOPLE & CREATORS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: textSecondary,
              ),
            ),
          ),
          ..._userResults.map((u) {
            final id = (u['id'] as num?)?.toInt() ?? 0;
            final name = u['name']?.toString() ?? '';
            final username = u['username']?.toString() ?? '';
            final avatarUrl = (u['avatar_url'] ?? u['avatar'])?.toString();
            final bio = u['bio']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onTap: () {
                  context.push('/profile/user/$id?username=$username&name=${Uri.encodeComponent(name)}');
                },
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF007AFF), fontWeight: FontWeight.w500),
                    ),
                    if (bio != null && bio.isNotEmpty)
                      Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8E8E93)),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (_communityResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'COMMUNITIES & CHANNELS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: textSecondary,
              ),
            ),
          ),
          ..._communityResults.map((c) {
            final name = c['name']?.toString() ?? '';
            final slug = c['slug']?.toString() ?? '';
            final logoUrl = c['logo_url']?.toString();
            final memberCount = (c['member_count'] as num?)?.toInt() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onTap: () {
                  context.push('/app/community/$slug');
                },
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF5856D6).withOpacity(0.15),
                  backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(logoUrl)
                      : null,
                  child: logoUrl == null || logoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5856D6)),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                ),
                subtitle: Text(
                  '$memberCount members',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8E8E93)),
              ),
            );
          }),
        ],
      ],
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
