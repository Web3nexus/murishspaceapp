import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/broadcast_channel_models.dart';

class BroadcastChannelsState {
  final bool loading;
  final String? error;
  final List<BroadcastChannel> channels;

  const BroadcastChannelsState({
    this.loading = false,
    this.error,
    this.channels = const [],
  });

  BroadcastChannelsState copyWith({
    bool? loading,
    String? error,
    List<BroadcastChannel>? channels,
    bool clearError = false,
  }) {
    return BroadcastChannelsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      channels: channels ?? this.channels,
    );
  }
}

List<BroadcastChannel> _extractChannels(dynamic rawData) {
  if (rawData == null) return [];
  dynamic target = rawData;
  if (target is Map<String, dynamic>) {
    if (target.containsKey('data')) target = target['data'];
  }
  if (target is Map<String, dynamic>) {
    if (target.containsKey('data')) target = target['data'];
  }
  if (target is List) {
    return target
        .whereType<Map<String, dynamic>>()
        .map(BroadcastChannel.fromJson)
        .toList();
  }
  return [];
}

class BroadcastChannelsNotifier extends Notifier<BroadcastChannelsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  BroadcastChannelsState build() {
    _load();
    return const BroadcastChannelsState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/broadcast-channels');
      final list = _extractChannels(response.data);
      state = BroadcastChannelsState(channels: list, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: _errorMessage(e),
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// Creates a broadcast channel linked to an entity the current user owns.
  ///
  /// [linkedType] decides the audience: your page (friends + followers), a
  /// group you own/admin, or a community you own. Recipients are derived
  /// server-side — you can never manually add arbitrary users.
  Future<BroadcastChannel?> create({
    required String name,
    String? handle,
    String? description,
    required bool allowReplies,
    required BroadcastLinkedType linkedType,
    int? linkedId,
  }) async {
    try {
      final response = await _dio.post('/broadcast-channels', data: {
        'name': name,
        if (handle != null && handle.isNotEmpty) 'handle': handle,
        if (description != null && description.isNotEmpty)
          'description': description,
        'allow_replies': allowReplies,
        'linked_type': linkedType.apiValue,
        'linked_id': linkedId,
      });
      final payload = ApiClient.instance.unwrap(response);
      final channelJson = payload is Map<String, dynamic> && payload['channel'] is Map<String, dynamic>
          ? payload['channel']
          : payload;
      final channel = BroadcastChannel.fromJson(channelJson);
      if (channel.id == 0) {
        throw ApiException(message: 'Unexpected response while creating the broadcast channel.');
      }
      final existing = state.channels.where((c) => c.id != channel.id).toList();
      state = state.copyWith(channels: [channel, ...existing], clearError: true);
      return channel;
    } on DioException catch (e) {
      throw ApiException(message: _errorMessage(e));
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? 'Could not create broadcast channel.';
    }
    return 'Could not create broadcast channel.';
  }
}

final myBroadcastChannelsProvider =
    NotifierProvider<BroadcastChannelsNotifier, BroadcastChannelsState>(
  BroadcastChannelsNotifier.new,
);