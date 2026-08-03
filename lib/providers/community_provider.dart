import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/community_models.dart';
import 'auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────
// My communities
// ─────────────────────────────────────────────────────────────────────────

class CommunitiesState {
  final bool loading;
  final String? error;
  final List<Community> communities;

  const CommunitiesState({
    this.loading = false,
    this.error,
    this.communities = const [],
  });

  CommunitiesState copyWith({
    bool? loading,
    String? error,
    List<Community>? communities,
    bool clearError = false,
  }) {
    return CommunitiesState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      communities: communities ?? this.communities,
    );
  }
}

class MyCommunitiesNotifier extends Notifier<CommunitiesState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  CommunitiesState build() {
    _load();
    return const CommunitiesState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/my-communities');
      final data = response.data;
      final raw = data is Map<String, dynamic> ? data['communities'] : null;
      final list = raw is List ? raw.map(Community.fromJson).toList() : <Community>[];
      state = CommunitiesState(communities: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load communities.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  void upsert(Community community) {
    final list = [community, ...state.communities.where((c) => c.id != community.id)];
    state = state.copyWith(communities: list, clearError: true);
  }

  void remove(int communityId) {
    state = state.copyWith(
      communities: state.communities.where((c) => c.id != communityId).toList(),
    );
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load communities.';
    return 'Failed to load communities.';
  }
}

final myCommunitiesProvider =
    NotifierProvider<MyCommunitiesNotifier, CommunitiesState>(MyCommunitiesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Discover (public browse + search)
// ─────────────────────────────────────────────────────────────────────────

class DiscoverState {
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final List<Community> communities;

  const DiscoverState({
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.communities = const [],
  });

  DiscoverState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    List<Community>? communities,
    bool clearError = false,
  }) {
    return DiscoverState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      communities: communities ?? this.communities,
    );
  }
}

class DiscoverCommunitiesNotifier extends Notifier<DiscoverState> {
  Dio get _dio => ApiClient.instance.dio;
  int _page = 1;
  String _query = '';

  @override
  DiscoverState build() {
    _load();
    return const DiscoverState(loading: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final response = await _dio.get('/communities', queryParameters: {
        'page': _page,
        if (_query.isNotEmpty) 'search': _query,
      });
      final payload = ApiClient.instance.unwrap(response);
      final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
      final list = rawList is List ? rawList.map(Community.fromJson).toList() : <Community>[];
      final hasMore = payload is Map<String, dynamic> && (payload['next_page_url'] as String?) != null;
      _page += 1;
      state = DiscoverState(
        loading: false,
        loadingMore: false,
        hasMore: hasMore,
        communities: reset || state.communities.isEmpty ? list : [...state.communities, ...list],
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, loadingMore: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, loadingMore: false, error: 'Failed to load communities.');
    }
  }

  Future<void> search(String query) {
    _query = query.trim();
    return _load(reset: true);
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    await _load();
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load communities.';
    return 'Failed to load communities.';
  }
}

final discoverCommunitiesProvider =
    NotifierProvider<DiscoverCommunitiesNotifier, DiscoverState>(DiscoverCommunitiesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Posts feed (global ranked feed + per-community feed share one notifier)
// ─────────────────────────────────────────────────────────────────────────

class PostsSource {
  final int? communityId;
  final String? feedType;

  const PostsSource.community(int id)
      : communityId = id,
        feedType = null;
  const PostsSource.feed(String type)
      : communityId = null,
        feedType = type;

  @override
  bool operator ==(Object other) =>
      other is PostsSource && other.communityId == communityId && other.feedType == feedType;

  @override
  int get hashCode => Object.hash(communityId, feedType);
}

class PostsState {
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final List<Post> posts;

  const PostsState({
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.posts = const [],
  });

  PostsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    List<Post>? posts,
    bool clearError = false,
  }) {
    return PostsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      posts: posts ?? this.posts,
    );
  }
}

class PostsNotifier extends Notifier<PostsState> {
  PostsNotifier(this.source);

  final PostsSource source;
  int _page = 1;

  Dio get _dio => ApiClient.instance.dio;

  @override
  PostsState build() {
    _load();
    return const PostsState(loading: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final path = source.communityId != null
          ? '/communities/${source.communityId}/posts'
          : '/feed/ranked';
      final query = source.communityId != null
          ? {'page': _page}
          : {'page': _page, 'feed_type': source.feedType ?? 'home'};
      final response = await _dio.get(path, queryParameters: query);
      final payload = ApiClient.instance.unwrap(response);
      final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
      final list = rawList is List ? rawList.map(Post.fromJson).toList() : <Post>[];
      final hasMore = payload is Map<String, dynamic> && (payload['next_page_url'] as String?) != null;
      _page += 1;
      final myId = ref.read(authProvider).user?.id;
      final hydrated = myId == null
          ? list
          : list
              .map((p) => p.copyWith(likedByMe: p.reactions.any((r) => r.userId == myId)))
              .toList();
      state = PostsState(
        loading: false,
        loadingMore: false,
        hasMore: hasMore,
        posts: reset || state.posts.isEmpty ? hydrated : [...state.posts, ...hydrated],
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, loadingMore: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, loadingMore: false, error: 'Failed to load posts.');
    }
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    await _load();
  }

  /// Marks which posts the current user already liked, from reaction rows.
  void hydrateMyReactions(int myId) {
    state = state.copyWith(
      posts: state.posts
          .map((p) => p.copyWith(likedByMe: p.reactions.any((r) => r.userId == myId)))
          .toList(),
    );
  }

  void prepend(Post post) {
    state = state.copyWith(posts: [post, ...state.posts], clearError: true);
  }

  void _replace(Post updated) {
    state = state.copyWith(
      posts: state.posts.map((p) => p.id == updated.id ? updated : p).toList(),
    );
  }

  Future<void> toggleLike(Post post, {required int myId}) async {
    final target = post.copyWith(likedByMe: !post.likedByMe, likesCount: (post.likesCount + (post.likedByMe ? -1 : 1)).clamp(0, 1 << 31));
    _replace(target);
    try {
      await _dio.post('/posts/${post.id}/reactions/toggle', data: {'reaction_type': 'like'});
    } catch (_) {
      _replace(post);
    }
  }

  Future<void> toggleSave(Post post) async {
    final target = post.copyWith(savedByMe: !post.savedByMe, savesCount: (post.savesCount + (post.savedByMe ? -1 : 1)).clamp(0, 1 << 31));
    _replace(target);
    try {
      await _dio.post('/posts/${post.id}/save');
    } catch (_) {
      _replace(post);
    }
  }

  /// Shares a post (increments the share count server-side) and confirms.
  Future<void> share(Post post) async {
    final target = post.copyWith(sharesCount: post.sharesCount + 1);
    _replace(target);
    try {
      await _dio.post('/posts/${post.id}/share');
    } catch (_) {
      _replace(post);
    }
  }

  Future<bool> addComment(Post post, String content) async {    try {
      final response = await _dio.post('/posts/${post.id}/comments', data: {'content': content});
      final payload = response.data;
      final raw = payload is Map<String, dynamic> ? payload['comment'] : null;
      _replace(post.copyWith(commentsCount: post.commentsCount + 1));
      return raw != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> report(Post post, String reason, {String? description}) async {
    try {
      await _dio.post('/posts/${post.id}/report', data: {
        'reason': reason,
        'description': ?description,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load posts.';
    return 'Failed to load posts.';
  }
}

final postsProvider =
    NotifierProvider.family<PostsNotifier, PostsState, PostsSource>(PostsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Saved posts
// ─────────────────────────────────────────────────────────────────────────

class SavedPostsNotifier extends Notifier<PostsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  PostsState build() {
    _load();
    return const PostsState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/posts/saved');
      final list = ApiClient.instance.unwrapList<Post>(response, Post.fromJson);
      state = PostsState(posts: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load saved posts.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  void remove(int postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  /// Un-saves a post on the server and removes it from the local list.
  Future<void> unsave(Post post) async {
    remove(post.id);
    try {
      await _dio.post('/posts/${post.id}/save');
    } catch (_) {
      // Local removal is intentional; the server call is best-effort.
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load saved posts.';
    return 'Failed to load saved posts.';
  }
}

final savedPostsProvider = NotifierProvider<SavedPostsNotifier, PostsState>(SavedPostsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Community detail (by slug) + membership
// ─────────────────────────────────────────────────────────────────────────

class CommunityDetailState {
  final bool loading;
  final String? error;
  final Community? community;
  final MembershipStatus? membership;

  const CommunityDetailState({
    this.loading = false,
    this.error,
    this.community,
    this.membership,
  });

  CommunityDetailState copyWith({
    bool? loading,
    String? error,
    Community? community,
    MembershipStatus? membership,
    bool clearError = false,
  }) {
    return CommunityDetailState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      community: community ?? this.community,
      membership: membership ?? this.membership,
    );
  }
}

class CommunityDetailNotifier extends Notifier<CommunityDetailState> {
  CommunityDetailNotifier(this.slug);

  final String slug;

  Dio get _dio => ApiClient.instance.dio;

  @override
  CommunityDetailState build() {
    _load();
    return const CommunityDetailState(loading: true);
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/communities/$slug');
      final payload = ApiClient.instance.unwrap(response);
      final community = Community.fromJson(payload is Map<String, dynamic> ? payload['community'] : null);
      MembershipStatus? membership;
      if (community.id != 0) {
        membership = await _loadMembership(community.id);
      }
      state = CommunityDetailState(community: community, membership: membership);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load community.');
    }
  }

  Future<MembershipStatus?> _loadMembership(int communityId) async {
    try {
      final response = await _dio.get('/communities/$communityId/membership-status');
      return MembershipStatus.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() => _load();

  Future<bool> join() async {
    final community = state.community;
    if (community == null) return false;
    try {
      final response = await _dio.post('/communities/${community.id}/join');
      final data = response.data;
      final status = data is Map<String, dynamic> ? data['status'] : null;
      state = state.copyWith(
        membership: MembershipStatus(
          isMember: status == 'active',
          isPending: status == 'pending',
          role: status == 'active' ? 'member' : null,
          status: status as String? ?? 'none',
        ),
      );
      if (status == 'active') {
        state = state.copyWith(
          community: Community(
            id: community.id,
            name: community.name,
            slug: community.slug,
            description: community.description,
            category: community.category,
            visibility: community.visibility,
            pricingType: community.pricingType,
            priceAmount: community.priceAmount,
            logoUrl: community.logoUrl,
            coverUrl: community.coverUrl,
            membersCount: community.membersCount + 1,
            creator: community.creator,
          ),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leave() async {
    final community = state.community;
    if (community == null) return false;
    try {
      await _dio.post('/communities/${community.id}/leave');
      state = state.copyWith(
        membership: const MembershipStatus(isMember: false, isPending: false, status: 'none'),
        community: Community(
          id: community.id,
          name: community.name,
          slug: community.slug,
          description: community.description,
          category: community.category,
          visibility: community.visibility,
          pricingType: community.pricingType,
          priceAmount: community.priceAmount,
          logoUrl: community.logoUrl,
          coverUrl: community.coverUrl,
          membersCount: (community.membersCount - 1).clamp(0, 1 << 31),
          creator: community.creator,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load community.';
    return 'Failed to load community.';
  }
}

final communityDetailProvider =
    NotifierProvider.family<CommunityDetailNotifier, CommunityDetailState, String>(
  CommunityDetailNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────
// Community members
// ─────────────────────────────────────────────────────────────────────────

class CommunityMembersState {
  final bool loading;
  final String? error;
  final List<CommunityMember> members;

  const CommunityMembersState({
    this.loading = false,
    this.error,
    this.members = const [],
  });

  CommunityMembersState copyWith({
    bool? loading,
    String? error,
    List<CommunityMember>? members,
    bool clearError = false,
  }) {
    return CommunityMembersState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      members: members ?? this.members,
    );
  }
}

class CommunityMembersNotifier extends Notifier<CommunityMembersState> {
  CommunityMembersNotifier(this.communityId);

  final int communityId;

  Dio get _dio => ApiClient.instance.dio;

  @override
  CommunityMembersState build() {
    _load();
    return const CommunityMembersState(loading: true);
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/communities/$communityId/members');
      final list = ApiClient.instance.unwrapList<CommunityMember>(
        response,
        CommunityMember.fromJson,
      );
      state = CommunityMembersState(members: list);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      state = state.copyWith(loading: false, error: message ?? 'Failed to load members.');
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load members.');
    }
  }

  Future<void> refresh() {
    state = state.copyWith(loading: true, clearError: true);
    return _load();
  }
}

final communityMembersProvider =
    NotifierProvider.family<CommunityMembersNotifier, CommunityMembersState, int>(
  CommunityMembersNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────
// Pending join requests (creator moderation)
// ─────────────────────────────────────────────────────────────────────────

class CommunityRequestsState {
  final bool loading;
  final String? error;
  final List<CommunityMember> requests;

  const CommunityRequestsState({
    this.loading = false,
    this.error,
    this.requests = const [],
  });

  CommunityRequestsState copyWith({
    bool? loading,
    String? error,
    List<CommunityMember>? requests,
    bool clearError = false,
  }) {
    return CommunityRequestsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      requests: requests ?? this.requests,
    );
  }
}

class CommunityRequestsNotifier extends Notifier<CommunityRequestsState> {
  CommunityRequestsNotifier(this.communityId);

  final int communityId;

  Dio get _dio => ApiClient.instance.dio;

  @override
  CommunityRequestsState build() {
    _load();
    return const CommunityRequestsState(loading: true);
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/communities/$communityId/requests');
      final payload = ApiClient.instance.unwrap(response);
      final raw = payload is Map<String, dynamic> ? payload['requests'] : null;
      final list = raw is List
          ? raw.whereType<Map<String, dynamic>>().map(CommunityMember.fromJson).toList()
          : <CommunityMember>[];
      state = CommunityRequestsState(requests: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load join requests.');
    }
  }

  Future<void> refresh() {
    state = state.copyWith(loading: true, clearError: true);
    return _load();
  }

  Future<void> _resolve(CommunityMember request, bool approve) async {
    final path = approve
        ? '/memberships/${request.id}/approve'
        : '/memberships/${request.id}/reject';
    try {
      await _dio.post(path);
      state = state.copyWith(
        requests: state.requests.where((r) => r.id != request.id).toList(),
      );
    } catch (_) {
      // Keep the request so the user can retry.
    }
  }

  Future<void> approve(CommunityMember request) => _resolve(request, true);

  Future<void> reject(CommunityMember request) => _resolve(request, false);

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load join requests.';
    return 'Failed to load join requests.';
  }
}

final communityRequestsProvider =
    NotifierProvider.family<CommunityRequestsNotifier, CommunityRequestsState, int>(
  CommunityRequestsNotifier.new,
);
