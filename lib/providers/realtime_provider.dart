import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/realtime_client.dart';
import '../models/chat_models.dart';
import 'chat_provider.dart';
import 'messages_provider.dart';

/// Connects to Reverb and routes broadcast events into chat state.
class RealtimeService {
  RealtimeService(this._ref);

  final Ref _ref;
  ReverbClient? _client;
  final Set<int> _subscribed = {};

  /// Ensures the socket is connected and subscribed to the conversation's
  /// private channel. Idempotent per conversation.
  void enterConversation(int conversationId) {
    if (_subscribed.contains(conversationId)) return;
    _subscribed.add(conversationId);
    final client = _ensureClient();
    if (client.isConnected) {
      client.subscribe('private-conversation.$conversationId');
    }
  }

  ReverbClient _ensureClient() {
    if (_client == null) {
      _client = ReverbClient(
        postJson: (url, body) => ApiClient.broadcastAuth(
          socketId: (body['socket_id'] as String?) ?? '',
          channelName: (body['channel_name'] as String?) ?? '',
        ),
      );
      _client!.events.listen(_dispatch);
    }
    _client!.connect();
    return _client!;
  }

  void _dispatch(RealtimeEvent event) {
    final match = RegExp(r'^private-conversation\.(\d+)$').firstMatch(event.channel);
    if (match == null) return;
    final conversationId = int.parse(match.group(1)!);
    final notifier = _ref.read(conversationMessagesProvider(conversationId).notifier);

    switch (event.event) {
      case 'App\\Events\\MessageSent':
        notifier.applyRealtime(Message.fromJson(event.data));
      case 'MessageDeleted':
        final data = event.data is Map ? (event.data as Map) : const {};
        final messageId = (data['id'] as num?)?.toInt() ?? 0;
        if (messageId > 0) notifier.applyRealtimeDeleted(messageId);
      case 'App\\Events\\MessageReacted':
        final data = event.data is Map ? (event.data as Map) : const {};
        final messageId = (data['message_id'] as num?)?.toInt() ?? 0;
        final raw = data['reactions'];
        final reactions = raw is List
            ? raw.map(ReactionSummary.fromJson).toList()
            : <ReactionSummary>[];
        if (messageId > 0) notifier.applyRealtimeReaction(messageId, reactions);
      case 'typing':
        final data = event.data is Map ? (event.data as Map) : const {};
        final userId = (data['user_id'] as num?)?.toInt() ?? 0;
        final isTyping = data['is_typing'] as bool? ?? false;
        if (userId == 0) return;
        final typing = _ref.read(typingProvider.notifier);
        if (isTyping) {
          typing.setTyping(conversationId, userId, data['user_name'] as String? ?? '');
        } else {
          typing.clearTyping(conversationId, userId);
        }
    }
  }

  void dispose() {
    _client?.dispose();
    _client = null;
    _subscribed.clear();
  }
}

final realtimeProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref);
  ref.onDispose(service.dispose);
  return service;
});
