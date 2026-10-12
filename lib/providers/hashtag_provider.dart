import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateNotifier / StateNotifierProvider here.
import 'package:flutter_riverpod/legacy.dart';

import '../core/api_client.dart';

class HashtagModel {
  final String tag;
  final String displayTag;
  final int postsCount;
  final String? lastUsedAt;
  final double? trendScore;
  final double? growth;
  final bool? isGrowing;

  HashtagModel({
    required this.tag,
    required this.displayTag,
    required this.postsCount,
    this.lastUsedAt,
    this.trendScore,
    this.growth,
    this.isGrowing,
  });

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag'] ?? '').toString();
    return HashtagModel(
      tag: tag,
      displayTag: tag.startsWith('#') ? tag : (tag.isNotEmpty ? '#$tag' : ''),
      postsCount: ((json['posts_count'] ?? json['raw_count']) as num?)?.toInt() ?? 0,
      lastUsedAt: json['last_used_at']?.toString(),
      trendScore: (json['trend_score'] as num?)?.toDouble(),
      growth: (json['growth'] as num?)?.toDouble(),
      isGrowing: json['is_growing'] as bool?,
    );
  }
}

class TrendingTopicsState {
  final List<HashtagModel> topics;
  final bool loading;
  final String? error;

  const TrendingTopicsState({
    this.topics = const [],
    this.loading = true,
    this.error,
  });

  TrendingTopicsState copyWith({
    List<HashtagModel>? topics,
    bool? loading,
    String? error,
  }) {
    return TrendingTopicsState(
      topics: topics ?? this.topics,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

final hashtagServiceProvider = Provider<HashtagService>((ref) {
  return HashtagService(ApiClient.instance);
});

final trendingTopicsProvider =
    StateNotifierProvider<TrendingTopicsNotifier, TrendingTopicsState>((ref) {
  return TrendingTopicsNotifier(ref.read(hashtagServiceProvider));
});

final hashtagSuggestionsProvider =
    FutureProvider.family<List<HashtagModel>, String>((ref, query) async {
  final service = ref.read(hashtagServiceProvider);
  return service.suggest(query.trim());
});

class HashtagService {
  final ApiClient _api;

  HashtagService(this._api);

  Future<List<HashtagModel>> trending({int limit = 10}) async {
    try {
      final res = await _api.dio.get('/discover/trending', queryParameters: {
        'limit': limit,
      });
      final data = _api.unwrap(res);
      final topics = data is Map<String, dynamic>
          ? (data['trending_topics'] as List? ?? [])
          : const [];
      return topics
          .whereType<Map<String, dynamic>>()
          .map(HashtagModel.fromJson)
          .toList();
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) throw _api.unwrap(response);
      rethrow;
    }
  }

  Future<List<HashtagModel>> suggest(String query, {int limit = 10}) async {
    if (query.isEmpty) {
      return [];
    }
    try {
      final res = await _api.dio.get('/discover/hashtags/suggest', queryParameters: {
        'q': query,
        'limit': limit,
      });
      final data = _api.unwrap(res);
      final items = data is Map<String, dynamic>
          ? ((data['hashtags'] as List?) ?? (data['data'] as List?) ?? [])
          : (data is List ? data : []);
      return items
          .whereType<Map<String, dynamic>>()
          .map(HashtagModel.fromJson)
          .toList();
    } on DioException {
      return [];
    }
  }
}

class TrendingTopicsNotifier extends StateNotifier<TrendingTopicsState> {
  final HashtagService _service;

  TrendingTopicsNotifier(this._service) : super(const TrendingTopicsState()) {
    fetch();
  }

  Future<void> fetch({int limit = 10}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final topics = await _service.trending(limit: limit);
      state = state.copyWith(topics: topics, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        topics: const [],
      );
    }
  }
}
