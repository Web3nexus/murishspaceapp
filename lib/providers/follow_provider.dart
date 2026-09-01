import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class UserFollowSummary {
  final int userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;
  final String role;
  final bool isVerified;
  final bool isFollowing;

  UserFollowSummary({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl = '',
    this.bio = '',
    this.role = 'member',
    this.isVerified = false,
    this.isFollowing = false,
  });

  factory UserFollowSummary.fromJson(Map<String, dynamic> json) {
    return UserFollowSummary(
      userId: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'User',
      username: json['username'] as String? ?? 'user',
      avatarUrl: json['avatar'] as String? ?? json['avatar_url'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      isVerified: json['is_verified'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }
}

class FollowState {
  final Set<int> followingUserIds;
  final Map<int, int> followersCounts;
  final Map<int, int> followingCounts;
  final Map<int, int> userPostsCounts;
  final Map<int, List<UserFollowSummary>> followersLists;
  final Map<int, List<UserFollowSummary>> followingLists;
  final bool loading;

  FollowState({
    required this.followingUserIds,
    required this.followersCounts,
    required this.followingCounts,
    required this.userPostsCounts,
    this.followersLists = const {},
    this.followingLists = const {},
    this.loading = false,
  });

  bool isFollowing(int userId) => followingUserIds.contains(userId);

  int getFollowersCount(int userId) => followersCounts[userId] ?? 0;
  int getFollowingCount(int userId) => followingCounts[userId] ?? 0;
  int getPostsCount(int userId) => userPostsCounts[userId] ?? 0;

  FollowState copyWith({
    Set<int>? followingUserIds,
    Map<int, int>? followersCounts,
    Map<int, int>? followingCounts,
    Map<int, int>? userPostsCounts,
    Map<int, List<UserFollowSummary>>? followersLists,
    Map<int, List<UserFollowSummary>>? followingLists,
    bool? loading,
  }) {
    return FollowState(
      followingUserIds: followingUserIds ?? this.followingUserIds,
      followersCounts: followersCounts ?? this.followersCounts,
      followingCounts: followingCounts ?? this.followingCounts,
      userPostsCounts: userPostsCounts ?? this.userPostsCounts,
      followersLists: followersLists ?? this.followersLists,
      followingLists: followingLists ?? this.followingLists,
      loading: loading ?? this.loading,
    );
  }
}

class FollowNotifier extends Notifier<FollowState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  FollowState build() {
    return FollowState(
      followingUserIds: {},
      followersCounts: {},
      followingCounts: {},
      userPostsCounts: {},
    );
  }

  /// Fetches follow status and counts for a user from the backend API.
  Future<void> fetchFollowStatus(int userId) async {
    try {
      final res = await _dio.get('/users/$userId/follow-status');
      final data = ApiClient.instance.unwrap(res) as Map<String, dynamic>;

      final isFollowing = data['is_following'] as bool? ?? false;
      final followers = (data['followers_count'] as num?)?.toInt() ?? 0;
      final following = (data['following_count'] as num?)?.toInt() ?? 0;
      final posts = (data['posts_count'] as num?)?.toInt() ?? 0;

      final updatedFollowing = Set<int>.from(state.followingUserIds);
      if (isFollowing) {
        updatedFollowing.add(userId);
      } else {
        updatedFollowing.remove(userId);
      }

      final fCounts = Map<int, int>.from(state.followersCounts)..[userId] = followers;
      final fingCounts = Map<int, int>.from(state.followingCounts)..[userId] = following;
      final pCounts = Map<int, int>.from(state.userPostsCounts)..[userId] = posts;

      state = state.copyWith(
        followingUserIds: updatedFollowing,
        followersCounts: fCounts,
        followingCounts: fingCounts,
        userPostsCounts: pCounts,
      );
    } catch (_) {}
  }

  /// Toggles follow status with live backend API call.
  Future<bool> toggleFollow(int targetUserId) async {
    final currentlyFollowing = state.isFollowing(targetUserId);
    final nextFollowing = !currentlyFollowing;

    // Optimistic UI update
    final updatedSet = Set<int>.from(state.followingUserIds);
    final fCounts = Map<int, int>.from(state.followersCounts);
    final currentTargetFollowers = fCounts[targetUserId] ?? 0;

    if (nextFollowing) {
      updatedSet.add(targetUserId);
      fCounts[targetUserId] = currentTargetFollowers + 1;
    } else {
      updatedSet.remove(targetUserId);
      fCounts[targetUserId] = (currentTargetFollowers > 0) ? currentTargetFollowers - 1 : 0;
    }

    state = state.copyWith(
      followingUserIds: updatedSet,
      followersCounts: fCounts,
    );

    try {
      final res = await _dio.post('/users/$targetUserId/follow');
      final data = ApiClient.instance.unwrap(res) as Map<String, dynamic>;

      final realIsFollowing = data['is_following'] as bool? ?? nextFollowing;
      final realFollowersCount = (data['target_followers_count'] as num?)?.toInt();

      if (realFollowersCount != null) {
        fCounts[targetUserId] = realFollowersCount;
      }
      if (realIsFollowing) {
        updatedSet.add(targetUserId);
      } else {
        updatedSet.remove(targetUserId);
      }

      state = state.copyWith(
        followingUserIds: updatedSet,
        followersCounts: fCounts,
      );
      return realIsFollowing;
    } catch (e) {
      // Rollback on network failure
      if (currentlyFollowing) {
        updatedSet.add(targetUserId);
        fCounts[targetUserId] = currentTargetFollowers;
      } else {
        updatedSet.remove(targetUserId);
        fCounts[targetUserId] = currentTargetFollowers;
      }
      state = state.copyWith(
        followingUserIds: updatedSet,
        followersCounts: fCounts,
      );
      return currentlyFollowing;
    }
  }

  /// Fetches followers list from the backend API.
  Future<List<UserFollowSummary>> fetchFollowers(int userId) async {
    try {
      final res = await _dio.get('/users/$userId/followers');
      final envelope = ApiClient.instance.unwrap(res);
      final rawItems = envelope is Map<String, dynamic> && envelope['data'] is List
          ? envelope['data'] as List
          : envelope is List
              ? envelope
              : [];

      final list = rawItems
          .map((item) => UserFollowSummary.fromJson(item as Map<String, dynamic>))
          .toList();

      final updatedLists = Map<int, List<UserFollowSummary>>.from(state.followersLists)..[userId] = list;
      state = state.copyWith(followersLists: updatedLists);
      return list;
    } catch (_) {
      return state.followersLists[userId] ?? [];
    }
  }

  /// Fetches following list from the backend API.
  Future<List<UserFollowSummary>> fetchFollowing(int userId) async {
    try {
      final res = await _dio.get('/users/$userId/following');
      final envelope = ApiClient.instance.unwrap(res);
      final rawItems = envelope is Map<String, dynamic> && envelope['data'] is List
          ? envelope['data'] as List
          : envelope is List
              ? envelope
              : [];

      final list = rawItems
          .map((item) => UserFollowSummary.fromJson(item as Map<String, dynamic>))
          .toList();

      final updatedLists = Map<int, List<UserFollowSummary>>.from(state.followingLists)..[userId] = list;
      state = state.copyWith(followingLists: updatedLists);
      return list;
    } catch (_) {
      return state.followingLists[userId] ?? [];
    }
  }

  void incrementPostsCount([int delta = 1, int? userId]) {
    if (userId != null) {
      final pCounts = Map<int, int>.from(state.userPostsCounts);
      pCounts[userId] = (pCounts[userId] ?? 0) + delta;
      state = state.copyWith(userPostsCounts: pCounts);
    }
  }

  List<UserFollowSummary> getFollowersList(int userId) => state.followersLists[userId] ?? [];
  List<UserFollowSummary> getFollowingList(int userId) => state.followingLists[userId] ?? [];
}

final followProvider = NotifierProvider<FollowNotifier, FollowState>(FollowNotifier.new);
