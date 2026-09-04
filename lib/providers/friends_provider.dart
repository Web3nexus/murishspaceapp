import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class FriendUserItem {
  final int id;
  final int requestId;
  final String name;
  final String username;
  final String? title;
  final String? avatarUrl;
  final int mutualCount;
  final bool isOnline;
  final String status; // 'none', 'pending_received', 'pending_sent', 'accepted'

  const FriendUserItem({
    required this.id,
    this.requestId = 0,
    required this.name,
    required this.username,
    this.title,
    this.avatarUrl,
    this.mutualCount = 0,
    this.isOnline = false,
    this.status = 'none',
  });

  factory FriendUserItem.fromJson(Map<String, dynamic> json, {String status = 'none', int requestId = 0}) {
    final userObj = json['friend'] is Map<String, dynamic>
        ? json['friend'] as Map<String, dynamic>
        : (json['sender'] is Map<String, dynamic>
            ? json['sender'] as Map<String, dynamic>
            : (json['receiver'] is Map<String, dynamic>
                ? json['receiver'] as Map<String, dynamic>
                : (json['user'] is Map<String, dynamic>
                    ? json['user'] as Map<String, dynamic>
                    : json)));

    final reqId = requestId > 0
        ? requestId
        : ((json['request_id'] as num?)?.toInt() ?? (userObj['request_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0);

    final resolvedStatus = (json['status'] as String?) ?? (userObj['status'] as String?) ?? status;

    return FriendUserItem(
      id: (userObj['id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      requestId: reqId,
      name: userObj['name']?.toString() ?? 'User',
      username: userObj['username']?.toString() ?? 'user',
      title: userObj['bio']?.toString() ?? userObj['title']?.toString() ?? 'Community Member',
      avatarUrl: userObj['avatar_url']?.toString() ?? userObj['avatar']?.toString(),
      mutualCount: (json['mutual_friends'] as num?)?.toInt() ?? (userObj['mutual_friends'] as num?)?.toInt() ?? 0,
      isOnline: (userObj['is_online'] as bool?) ?? false,
      status: resolvedStatus,
    );
  }
}

class FriendsState {
  final bool loading;
  final String? error;
  final List<FriendUserItem> requests;
  final List<FriendUserItem> sentRequests;
  final List<FriendUserItem> friends;
  final List<FriendUserItem> suggestions;

  const FriendsState({
    this.loading = false,
    this.error,
    this.requests = const [],
    this.sentRequests = const [],
    this.friends = const [],
    this.suggestions = const [],
  });

  FriendsState copyWith({
    bool? loading,
    String? error,
    List<FriendUserItem>? requests,
    List<FriendUserItem>? sentRequests,
    List<FriendUserItem>? friends,
    List<FriendUserItem>? suggestions,
    bool clearError = false,
  }) {
    return FriendsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      requests: requests ?? this.requests,
      sentRequests: sentRequests ?? this.sentRequests,
      friends: friends ?? this.friends,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class FriendsNotifier extends Notifier<FriendsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  FriendsState build() {
    loadAll();
    return const FriendsState(loading: true);
  }

  Future<void> loadAll() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _fetchRequests(),
        _fetchSentRequests(),
        _fetchFriends(),
        _fetchSuggestions(),
      ]);

      state = FriendsState(
        loading: false,
        requests: results[0],
        sentRequests: results[1],
        friends: results[2],
        suggestions: results[3],
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Could not fetch connections.');
    }
  }

  Future<List<FriendUserItem>> _fetchRequests() async {
    try {
      final res = await _dio.get('/friends/requests');
      final list = ApiClient.instance.unwrapList(res, (item) {
        final sender = item['sender'] as Map<String, dynamic>? ?? item;
        return FriendUserItem.fromJson(sender, status: 'pending_received', requestId: (item['id'] as num?)?.toInt() ?? 0);
      });
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<FriendUserItem>> _fetchSentRequests() async {
    try {
      final res = await _dio.get('/friends/requests/sent');
      final list = ApiClient.instance.unwrapList(res, (item) {
        final receiver = item['receiver'] as Map<String, dynamic>? ?? item;
        return FriendUserItem.fromJson(receiver, status: 'pending_sent', requestId: (item['id'] as num?)?.toInt() ?? 0);
      });
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<FriendUserItem>> _fetchFriends() async {
    try {
      final res = await _dio.get('/friends');
      final list = ApiClient.instance.unwrapList(res, (item) {
        return FriendUserItem.fromJson(item, status: 'accepted');
      });
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<FriendUserItem>> _fetchSuggestions({String? query}) async {
    try {
      final res = (query != null && query.trim().isNotEmpty)
          ? await _dio.get('/friends/search', queryParameters: {'q': query.trim()})
          : await _dio.get('/friends/suggestions');

      final list = ApiClient.instance.unwrapList(res, (item) {
        final serverStatus = (item['status'] as String?) ?? 'none';
        return FriendUserItem.fromJson(item, status: serverStatus);
      });
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> searchSuggestions(String query) async {
    final suggestions = await _fetchSuggestions(query: query);
    state = state.copyWith(suggestions: suggestions);
  }

  Future<Map<String, dynamic>?> fetchFriendshipStatus(int userId) async {
    try {
      final res = await _dio.get('/friends/$userId/status');
      return ApiClient.instance.unwrap(res) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> acceptRequest(FriendUserItem item) async {
    state = state.copyWith(
      requests: state.requests.where((r) => r.id != item.id).toList(),
      friends: [...state.friends, item],
    );
    try {
      await _dio.post('/friends/requests/${item.requestId}/accept');
    } catch (_) {}
  }

  Future<void> declineRequest(FriendUserItem item) async {
    state = state.copyWith(
      requests: state.requests.where((r) => r.id != item.id).toList(),
    );
    try {
      await _dio.post('/friends/requests/${item.requestId}/decline');
    } catch (_) {}
  }

  Future<void> sendRequest(FriendUserItem item) async {
    state = state.copyWith(
      suggestions: state.suggestions.where((s) => s.id != item.id).toList(),
      sentRequests: [...state.sentRequests, item],
    );
    try {
      await _dio.post('/friends/requests', data: {'user_id': item.id});
    } catch (_) {}
  }

  Future<bool> sendRequestToUserId(int userId) async {
    try {
      await _dio.post('/friends/requests', data: {'user_id': userId});
      await loadAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelSentRequest(FriendUserItem item) async {
    state = state.copyWith(
      sentRequests: state.sentRequests.where((s) => s.id != item.id).toList(),
    );
    try {
      await _dio.post('/friends/requests/${item.requestId}/cancel');
    } catch (_) {}
  }

  Future<void> cancelRequestById(int requestId) async {
    try {
      await _dio.post('/friends/requests/$requestId/cancel');
      await loadAll();
    } catch (_) {}
  }

  Future<void> unfriend(FriendUserItem item) async {
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != item.id).toList(),
    );
    try {
      await _dio.delete('/friends/${item.id}');
    } catch (_) {}
  }

  Future<bool> unfriendByUserId(int userId) async {
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != userId).toList(),
    );
    try {
      await _dio.delete('/friends/$userId');
      return true;
    } catch (_) {
      return false;
    }
  }
}

final friendsProvider = NotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);
