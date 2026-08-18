import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserFollowSummary {
  final int userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;
  final bool isVerified;

  UserFollowSummary({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl = '',
    this.bio = '',
    this.isVerified = false,
  });
}

class FollowState {
  final Set<int> followingUserIds;
  final Map<int, int> followersCounts;
  final Map<int, int> followingCounts;
  final Map<int, int> userPostsCounts;
  final List<UserFollowSummary> sampleUsers;

  FollowState({
    required this.followingUserIds,
    required this.followersCounts,
    required this.followingCounts,
    required this.userPostsCounts,
    required this.sampleUsers,
  });

  bool isFollowing(int userId) => followingUserIds.contains(userId);

  int getFollowersCount(int userId) => followersCounts[userId] ?? 1250;
  int getFollowingCount(int userId) => followingCounts[userId] ?? 430;
  int getPostsCount(int userId) => userPostsCounts[userId] ?? 24;

  FollowState copyWith({
    Set<int>? followingUserIds,
    Map<int, int>? followersCounts,
    Map<int, int>? followingCounts,
    Map<int, int>? userPostsCounts,
    List<UserFollowSummary>? sampleUsers,
  }) {
    return FollowState(
      followingUserIds: followingUserIds ?? this.followingUserIds,
      followersCounts: followersCounts ?? this.followersCounts,
      followingCounts: followingCounts ?? this.followingCounts,
      userPostsCounts: userPostsCounts ?? this.userPostsCounts,
      sampleUsers: sampleUsers ?? this.sampleUsers,
    );
  }
}

class FollowNotifier extends Notifier<FollowState> {
  @override
  FollowState build() {
    return FollowState(
      followingUserIds: {2, 4, 6},
      followersCounts: {
        1: 12450, // Current user
        2: 5400,
        3: 1200,
        4: 8900,
        5: 3200,
        6: 15400,
      },
      followingCounts: {
        1: 430, // Current user
        2: 210,
        3: 150,
        4: 640,
        5: 310,
        6: 980,
      },
      userPostsCounts: {
        1: 42,
        2: 18,
        3: 9,
        4: 65,
        5: 27,
        6: 112,
      },
      sampleUsers: [
        UserFollowSummary(userId: 2, name: 'Alice Freeman', username: 'alice_freeman', bio: 'Tech Reviewer & Video Creator 📹', isVerified: true),
        UserFollowSummary(userId: 3, name: 'Bob Smith', username: 'bob_tech', bio: 'Web3 & FinTech Specialist ⚡'),
        UserFollowSummary(userId: 4, name: 'Pulse Activewear', username: 'pulse_active', bio: 'Official Vendor Store for Premium Activewear 🏃‍♂️', isVerified: true),
        UserFollowSummary(userId: 5, name: 'Charlie Brown', username: 'charlie_b', bio: 'Digital Creator & Mobile App Dev 🚀'),
        UserFollowSummary(userId: 6, name: 'Apex Audio Tech', username: 'apex_audio', bio: 'High-Fidelity Audio Gear Vendor & Sponsor 🎧', isVerified: true),
        UserFollowSummary(userId: 7, name: 'Kemi Adebayo', username: 'kemi_brand', bio: 'Fashion Ambassador & Lifestyle Creator ✨'),
        UserFollowSummary(userId: 8, name: 'Chioma Eze', username: 'chioma_e', bio: 'Community Manager & Event Host 🌟'),
      ],
    );
  }

  void toggleFollow(int targetUserId) {
    final isAlreadyFollowing = state.followingUserIds.contains(targetUserId);
    final updatedFollowingSet = Set<int>.from(state.followingUserIds);

    final currentMyFollowers = Map<int, int>.from(state.followersCounts);
    final currentMyFollowing = Map<int, int>.from(state.followingCounts);

    const myUserId = 1; // Current user ID

    if (isAlreadyFollowing) {
      updatedFollowingSet.remove(targetUserId);
      currentMyFollowing[myUserId] = (currentMyFollowing[myUserId] ?? 430) - 1;
      currentMyFollowers[targetUserId] = (currentMyFollowers[targetUserId] ?? 100) - 1;
    } else {
      updatedFollowingSet.add(targetUserId);
      currentMyFollowing[myUserId] = (currentMyFollowing[myUserId] ?? 430) + 1;
      currentMyFollowers[targetUserId] = (currentMyFollowers[targetUserId] ?? 100) + 1;
    }

    state = state.copyWith(
      followingUserIds: updatedFollowingSet,
      followingCounts: currentMyFollowing,
      followersCounts: currentMyFollowers,
    );
  }

  void incrementPostsCount(int userId) {
    final currentPosts = Map<int, int>.from(state.userPostsCounts);
    currentPosts[userId] = (currentPosts[userId] ?? 0) + 1;
    state = state.copyWith(userPostsCounts: currentPosts);
  }

  void decrementPostsCount(int userId) {
    final currentPosts = Map<int, int>.from(state.userPostsCounts);
    final count = currentPosts[userId] ?? 0;
    if (count > 0) {
      currentPosts[userId] = count - 1;
      state = state.copyWith(userPostsCounts: currentPosts);
    }
  }

  List<UserFollowSummary> getFollowersList(int userId) {
    return state.sampleUsers;
  }

  List<UserFollowSummary> getFollowingList(int userId) {
    return state.sampleUsers.where((u) => state.followingUserIds.contains(u.userId)).toList();
  }
}

final followProvider = NotifierProvider<FollowNotifier, FollowState>(FollowNotifier.new);
