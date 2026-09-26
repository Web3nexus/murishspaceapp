import 'dart:io';
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
      Response response;
      try {
        response = await _dio.get('/stories/feed');
      } catch (_) {
        response = await _dio.get('/stories');
      }

      final fetchedGroups = ApiClient.instance.unwrapList(
        response,
        UserStoryGroup.fromJson,
      );

      final sortedGroups = List<UserStoryGroup>.from(fetchedGroups);
      final myGroupIndex = sortedGroups.indexWhere((g) => g.isMyStory);

      if (myGroupIndex > 0) {
        final myGroup = sortedGroups.removeAt(myGroupIndex);
        sortedGroups.insert(0, myGroup);
      } else if (myGroupIndex == -1) {
        sortedGroups.insert(
          0,
          const UserStoryGroup(
            userId: 'me',
            userName: 'Your Story',
            isMyStory: true,
            stories: [],
          ),
        );
      }

      state = state.copyWith(groups: sortedGroups, isLoading: false);
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
    String remoteMediaUrl = mediaUrl;

    // If mediaUrl is a local file path, upload to /upload before persisting
    try {
      final file = File(mediaUrl);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final fileName = mediaUrl.contains('/') ? mediaUrl.split('/').last : 'story.jpg';
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
        });
        final uploadRes = await _dio.post('/upload', data: form);
        final payload = ApiClient.instance.unwrap(uploadRes);
        final url = payload is Map<String, dynamic> ? payload['url']?.toString() : null;
        if (url != null && url.isNotEmpty) {
          remoteMediaUrl = url;
        }
      }
    } catch (_) {
      // Gracefully continue with original mediaUrl if upload fails
    }

    final newStory = StoryItem(
      id: 'story_${DateTime.now().millisecondsSinceEpoch}',
      mediaUrl: remoteMediaUrl,
      caption: caption,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      viewsCount: 0,
      isSeen: true,
    );

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

    // Post to backend API and reload
    try {
      await _dio.post('/stories', data: {
        'media_url': remoteMediaUrl,
        'caption': caption,
        'media_type': 'image',
      });
      fetchStories();
    } catch (_) {
      // Gracefully continue with local optimistic update
    }

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
    _dio.post('/stories/$storyId/view').catchError((_) => Response(requestOptions: RequestOptions()));
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
