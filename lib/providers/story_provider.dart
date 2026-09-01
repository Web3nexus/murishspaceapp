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

  /// Default initial stories for the authenticated user.
  static final List<UserStoryGroup> _defaultStoryGroups = [
    const UserStoryGroup(
      userId: 'me',
      userName: 'Your Story',
      isMyStory: true,
      stories: [],
    ),
  ];
}

final storyProvider = NotifierProvider<StoryNotifier, StoryState>(
  () => StoryNotifier(),
);
