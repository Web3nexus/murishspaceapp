import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/live_models.dart';

class LiveDiscoveryState {
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final List<LiveStream> streams;

  const LiveDiscoveryState({
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
    this.streams = const [],
  });

  bool get isEmpty => !loading && streams.isEmpty;

  LiveDiscoveryState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    List<LiveStream>? streams,
    bool clearError = false,
  }) {
    return LiveDiscoveryState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      streams: streams ?? this.streams,
    );
  }
}

/// Browses currently-live broadcasts from `GET /live` (a Laravel paginator of
/// live `LiveStream` rows with `host` and `community` eager-loaded).
///
/// Kept alive for the session so the home "Live Now" rail and the discovery
/// screen share a single fetch. Pull-to-refresh re-reads page one.
class LiveDiscoveryNotifier extends Notifier<LiveDiscoveryState> {
  int _page = 1;
  // Monotonic request generation. Bumped on every reset so an in-flight
  // loadMore/refresh whose response arrives late can be discarded instead of
  // appending a stale page or advancing the page cursor twice.
  int _gen = 0;
  // True while a reset (pull-to-refresh / silent poll) is in flight. A silent
  // refresh keeps `loading` false, so without this flag `loadMore` could start
  // mid-reset, request page 1 again under the new generation, and either
  // duplicate page 1 or skip page 2.
  bool _refreshing = false;
  // Ids of broadcasts this session has seen end. A refresh fired while the end
  // request was still in flight can return the row as live, so ended ids are
  // filtered out of every response. Stream ids are never reused.
  final Set<int> _endedIds = <int>{};

  Dio get _dio => ApiClient.instance.dio;

  @override
  LiveDiscoveryState build() {
    _load(reset: true);
    return const LiveDiscoveryState(loading: true);
  }

  Future<void> _load({bool reset = false, bool silent = false}) async {
    final gen = reset ? ++_gen : _gen;
    if (reset) {
      _page = 1;
      _refreshing = true;
      // A silent refresh keeps the current cards on screen (no skeleton flash)
      // while it re-reads page one in the background.
      state = state.copyWith(loading: !silent, clearError: true);
    }
    try {
      final response = await _dio.get(
        '/live',
        queryParameters: {'page': _page, 'per_page': 20},
      );
      if (gen != _gen) return;
      final payload = ApiClient.instance.unwrap(response);
      final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
      final list = rawList is List
          ? rawList
              .map(LiveStream.fromJson)
              .where((s) => s.isLive && s.status != 'ended' && !_endedIds.contains(s.id))
              .toList()
          : <LiveStream>[];
      final hasMore =
          payload is Map<String, dynamic> &&
          (payload['next_page_url'] as String?) != null;
      _page += 1;
      state = LiveDiscoveryState(
        loading: false,
        loadingMore: false,
        hasMore: hasMore,
        streams: reset ? list : [...state.streams, ...list],
      );
    } on DioException catch (e) {
      if (gen != _gen) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: _errorMessage(e),
      );
    } catch (_) {
      if (gen != _gen) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: 'Failed to load live streams.',
      );
    } finally {
      // Only the request that still owns the current generation clears the
      // flag; a newer reset has taken over otherwise.
      if (gen == _gen) _refreshing = false;
    }
  }

  /// Immediately removes an ended broadcast from the feed without waiting for network.
  void removeStream(int streamId) {
    _endedIds.add(streamId);
    state = state.copyWith(
      streams: state.streams.where((s) => s.id != streamId).toList(),
    );
  }

  Future<void> refresh({bool silent = false}) => _load(reset: true, silent: silent);

  Future<void> loadMore() async {
    if (_refreshing || state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    await _load();
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Failed to load live streams.';
  }
}

final liveDiscoveryProvider =
    NotifierProvider<LiveDiscoveryNotifier, LiveDiscoveryState>(
      LiveDiscoveryNotifier.new,
    );
