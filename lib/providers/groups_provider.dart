import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/group_models.dart';

// ─────────────────────────────────────────────────────────────────────────
// My groups (joined + owned)
// ─────────────────────────────────────────────────────────────────────────

class GroupsState {
  final bool loading;
  final String? error;
  final List<Group> groups;

  const GroupsState({
    this.loading = false,
    this.error,
    this.groups = const [],
  });

  GroupsState copyWith({
    bool? loading,
    String? error,
    List<Group>? groups,
    bool clearError = false,
  }) {
    return GroupsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      groups: groups ?? this.groups,
    );
  }
}

const List<Group> _fallbackDiscoverGroups = [];

List<Group> _extractGroupsList(dynamic rawData) {
  if (rawData == null) return [];
  dynamic target = rawData;
  if (target is Map<String, dynamic>) {
    if (target.containsKey('groups')) {
      target = target['groups'];
    } else if (target.containsKey('data')) {
      target = target['data'];
    }
  }
  if (target is Map<String, dynamic>) {
    if (target.containsKey('groups')) {
      target = target['groups'];
    } else if (target.containsKey('data')) {
      target = target['data'];
    }
  }
  if (target is List) {
    return target.whereType<Map<String, dynamic>>().map(Group.fromJson).toList();
  }
  return [];
}

class MyGroupsNotifier extends Notifier<GroupsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  GroupsState build() {
    _load();
    return const GroupsState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/groups/mine');
      final list = _extractGroupsList(response.data);
      state = GroupsState(groups: list, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, clearError: true);
    }
  }

  Future<void> refresh() => _load(showLoading: true);
}

final myGroupsProvider =
    NotifierProvider<MyGroupsNotifier, GroupsState>(MyGroupsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Discover groups (public browse + search)
// ─────────────────────────────────────────────────────────────────────────

class DiscoverGroupsState {
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final List<Group> groups;

  const DiscoverGroupsState({
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.groups = const [],
  });

  DiscoverGroupsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    List<Group>? groups,
    bool clearError = false,
  }) {
    return DiscoverGroupsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      groups: groups ?? this.groups,
    );
  }
}

class DiscoverGroupsNotifier extends Notifier<DiscoverGroupsState> {
  Dio get _dio => ApiClient.instance.dio;
  int _page = 1;
  String _query = '';
  int _generation = 0;

  @override
  DiscoverGroupsState build() {
    _load();
    return const DiscoverGroupsState(loading: true);
  }

  Future<void> _load({bool reset = false}) async {
    // Monotonic generation so a stale response (older query or an in-flight
    // loadMore) never overwrites newer results.
    final generation = ++_generation;
    if (reset) {
      _page = 1;
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final response = await _dio.get('/groups', queryParameters: {
        'page': _page,
        if (_query.isNotEmpty) 'search': _query,
      });
      if (generation != _generation) return;
      final list = _extractGroupsList(response.data);

      _page += 1;
      state = DiscoverGroupsState(
        loading: false,
        loadingMore: false,
        hasMore: list.length >= 18,
        groups: reset ? list : [...state.groups, ...list],
      );
    } catch (_) {
      if (generation != _generation) return;
      final fallbackList = state.groups.isNotEmpty ? state.groups : _fallbackDiscoverGroups;
      state = DiscoverGroupsState(
        loading: false,
        loadingMore: false,
        hasMore: false,
        error: 'Could not load groups.',
        groups: fallbackList,
      );
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

  /// Joins a group (or submits a request for private groups).
  Future<dynamic> joinGroup(int groupId) async {
    try {
      final response = await _dio.post('/groups/$groupId/join');
      refresh();
      return response.data;
    } catch (_) {
      return null;
    }
  }

  /// Leaves a group. Returns true only when the request actually succeeded,
  /// so callers can show a failure instead of a false success.
  Future<bool> leaveGroup(int groupId) async {
    try {
      await _dio.post('/groups/$groupId/leave');
      refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final discoverGroupsProvider =
    NotifierProvider<DiscoverGroupsNotifier, DiscoverGroupsState>(DiscoverGroupsNotifier.new);