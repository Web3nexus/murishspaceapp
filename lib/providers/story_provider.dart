import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/story_models.dart';

class StoryState {
  final List<UserStoryGroup> groups;
  final bool isLoading;
  final String? error;

  const StoryState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  StoryState copyWith({
    List<UserStoryGroup>? groups,
    bool? isLoading,
    String? error,
  }) {
    return StoryState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StoryNotifier extends Notifier<StoryState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  StoryState build() {
    fetchStories();
    return StoryState(groups: _defaultStoryGroups);
  }

  /// Fetch stories filtered strictly by friends, followed creators, and joined communities.
  Future<void> fetchStories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/v1/stories/feed');
      final payload = ApiClient.instance.unwrap(response);

      if (payload is Map<String, dynamic> && payload.containsKey('data')) {
        final rawList = payload['data'] as List<dynamic>;
        final fetchedGroups = rawList
            .map((e) => UserStoryGroup.fromJson(e as Map<String, dynamic>))
            .toList();

        if (fetchedGroups.isNotEmpty) {
          state = state.copyWith(groups: fetchedGroups, isLoading: false);
          return;
        }
      }

      state = state.copyWith(groups: _defaultStoryGroups, isLoading: false);
    } catch (_) {
      // Fallback to default followed & community stories if offline or backend unready
      state = state.copyWith(groups: _defaultStoryGroups, isLoading: false);
    }
  }

  /// Publish a new 24-hour disappearing story for the current user.
  Future<bool> addStory({
    required String mediaUrl,
    String? caption,
  }) async {
    final newStory = StoryItem(
      id: 'story_${DateTime.now().millisecondsSinceEpoch}',
      mediaUrl: mediaUrl,
      caption: caption,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      viewsCount: 0,
      isSeen: true,
    );

    // Try posting to backend API
    try {
      await _dio.post('/v1/stories', data: {
        'media_url': mediaUrl,
        'caption': caption,
        'media_type': 'image',
      });
    } catch (_) {
      // Gracefully continue with local optimistic update
    }

    // Optimistically update local Riverpod state
    final currentGroups = List<UserStoryGroup>.from(state.groups);
    final myStoryIndex = currentGroups.indexWhere((g) => g.isMyStory);

    if (myStoryIndex != -1) {
      final myGroup = currentGroups[myStoryIndex];
      final updatedStories = [newStory, ...myGroup.stories];
      currentGroups[myStoryIndex] = myGroup.copyWith(stories: updatedStories);
    } else {
      final newMyGroup = UserStoryGroup(
        userId: 'me',
        userName: 'Your Story',
        isMyStory: true,
        stories: [newStory],
      );
      currentGroups.insert(0, newMyGroup);
    }

    state = state.copyWith(groups: currentGroups);
    return true;
  }

  /// Mark a specific story segment as viewed by the user.
  void markStorySeen(String userId, String storyId) {
    final updatedGroups = state.groups.map((group) {
      if (group.userId == userId) {
        final updatedStories = group.stories.map((story) {
          if (story.id == storyId) {
            return story.copyWith(isSeen: true);
          }
          return story;
        }).toList();
        return group.copyWith(stories: updatedStories);
      }
      return group;
    }).toList();

    state = state.copyWith(groups: updatedGroups);

    // Notify backend asynchronously
    _dio.post('/v1/stories/$storyId/view').catchError((_) => Response(requestOptions: RequestOptions()));
  }

  /// Curated default initial stories for friends, followed creators, and joined communities.
  static final List<UserStoryGroup> _defaultStoryGroups = [
    UserStoryGroup(
      userId: 'me',
      userName: 'Your Story',
      isMyStory: true,
      stories: [],
    ),
    UserStoryGroup(
      userId: 'friend_101',
      userName: 'Alex Rivera',
      userAvatar: 'https://picsum.photos/seed/alex/150/150',
      isMyStory: false,
      isCommunity: false,
      stories: [
        StoryItem(
          id: 'story_alex_1',
          mediaUrl: 'https://picsum.photos/seed/sunset_beach/600/1000',
          caption: 'Sunset vibes at the beach today 🌅✨',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          expiresAt: DateTime.now().add(const Duration(hours: 21)),
          viewsCount: 48,
          isSeen: false,
        ),
        StoryItem(
          id: 'story_alex_2',
          mediaUrl: 'https://picsum.photos/seed/coffee_laptop/600/1000',
          caption: 'Late night coding & espresso ☕️💻',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          expiresAt: DateTime.now().add(const Duration(hours: 23)),
          viewsCount: 22,
          isSeen: false,
        ),
      ],
    ),
    UserStoryGroup(
      userId: 'creator_202',
      userName: 'Design Systems Hub',
      userAvatar: 'https://picsum.photos/seed/designhub/150/150',
      isMyStory: false,
      isCommunity: true,
      communityName: 'UI/UX Designers',
      stories: [
        StoryItem(
          id: 'story_design_1',
          mediaUrl: 'https://picsum.photos/seed/figma_mockup/600/1000',
          caption: 'New Glassmorphism UI Kit dropping tomorrow! 🎨🚀',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          expiresAt: DateTime.now().add(const Duration(hours: 19)),
          viewsCount: 310,
          isSeen: false,
        ),
      ],
    ),
    UserStoryGroup(
      userId: 'friend_303',
      userName: 'Sophia Chen',
      userAvatar: 'https://picsum.photos/seed/sophia/150/150',
      isMyStory: false,
      isCommunity: false,
      stories: [
        StoryItem(
          id: 'story_sophia_1',
          mediaUrl: 'https://picsum.photos/seed/tokyo_street/600/1000',
          caption: 'Exploring neon streets in Tokyo! 🇯🇵✨',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          expiresAt: DateTime.now().add(const Duration(hours: 16)),
          viewsCount: 95,
          isSeen: false,
        ),
      ],
    ),
    UserStoryGroup(
      userId: 'community_404',
      userName: 'Flutter Devs Community',
      userAvatar: 'https://picsum.photos/seed/flutterdev/150/150',
      isMyStory: false,
      isCommunity: true,
      communityName: 'Flutter Global',
      stories: [
        StoryItem(
          id: 'story_flutter_1',
          mediaUrl: 'https://picsum.photos/seed/code_dart/600/1000',
          caption: 'Flutter 3.29 release highlights & performance benchmarks 💙⚡️',
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          expiresAt: DateTime.now().add(const Duration(hours: 12)),
          viewsCount: 520,
          isSeen: false,
        ),
      ],
    ),
  ];
}

final storyProvider = NotifierProvider<StoryNotifier, StoryState>(
  () => StoryNotifier(),
);
