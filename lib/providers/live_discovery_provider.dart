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

  Dio get _dio => ApiClient.instance.dio;

  @override
  LiveDiscoveryState build() {
    _load();
    return const LiveDiscoveryState(loading: true);
  }

  Future<void> _load({bool reset = false}) async {
    final gen = reset ? ++_gen : _gen;
    if (reset) {
      _page = 1;
      state = state.copyWith(loading: true, clearError: true);
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
          ? rawList.map(LiveStream.fromJson).toList()
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
    }
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
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
