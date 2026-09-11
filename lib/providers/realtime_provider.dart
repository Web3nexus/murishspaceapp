import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/in_app_notification_overlay.dart';
import '../core/api_client.dart';
import '../core/realtime_client.dart';
import '../models/chat_models.dart';
import '../models/notification_models.dart';
import 'auth_provider.dart';
import 'calls_provider.dart';
import 'chat_provider.dart';
import 'messages_provider.dart';
import 'notifications_provider.dart';

/// Connects to Reverb and routes broadcast events into chat and notification state.
class RealtimeService {
  RealtimeService(this._ref);

  final Ref _ref;
  ReverbClient? _client;
  final Set<int> _subscribedConversations = {};
  int? _userId;
  int? _activeConversationId;

  /// Subscribes to the user's personal private notification and call channels.
  void listenToUser(int userId) {
    if (_userId == userId && _client != null && _client!.isConnected) return;
    _userId = userId;
    final client = _ensureClient();
    client.subscribe('private-App.Models.User.$userId');
    client.subscribe('private-user.$userId');
  }

  /// Marks which conversation the user is currently viewing to suppress duplicate banners.
  void setActiveConversation(int? conversationId) {
    _activeConversationId = conversationId;
  }

  /// Ensures the socket is connected and subscribed to the conversation's
  /// private channel. Idempotent per conversation.
  void enterConversation(int conversationId) {
    setActiveConversation(conversationId);
    if (_subscribedConversations.contains(conversationId)) return;
    _subscribedConversations.add(conversationId);
    final client = _ensureClient();
    client.subscribe('private-conversation.$conversationId');
  }

  void leaveConversation(int conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
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
    // 1. Personal user notification & call signaling channels
    final userMatch = RegExp(r'^private-(?:App\.Models\.User|user)\.(\d+)$').firstMatch(event.channel);
    if (userMatch != null) {
      final data = event.data is Map
          ? Map<String, dynamic>.from(event.data as Map)
          : <String, dynamic>{};

      if (event.event == 'call.incoming' || event.event.contains('CallIncoming')) {
        _ref.read(callsProvider.notifier).handleIncomingCall(data);
        return;
      }
      if (event.event == 'call.accepted' || event.event.contains('CallAccepted')) {
        _ref.read(callsProvider.notifier).handleCallAccepted(data);
        return;
      }
      if (event.event == 'call.declined' || event.event.contains('CallDeclined')) {
        _ref.read(callsProvider.notifier).handleCallDeclined(data);
        return;
      }
      if (event.event == 'call.ended' || event.event.contains('CallEnded')) {
        _ref.read(callsProvider.notifier).handleCallEnded(data);
        return;
      }

      if (event.event == 'notification' || event.event.contains('NotificationBroadcast')) {
        try {
          final notif = AppNotification.fromJson(data);
          _ref.read(inAppNotificationProvider.notifier).showFromAppNotification(notif);
          _ref.read(notificationsProvider.notifier).refresh();
        } catch (_) {}
      }
      return;
    }

    // 2. Conversation messages & events
    final match = RegExp(r'^private-conversation\.(\d+)$').firstMatch(event.channel);
    if (match == null) return;
    final conversationId = int.parse(match.group(1)!);
    final notifier = _ref.read(conversationMessagesProvider(conversationId).notifier);

    switch (event.event) {
      case 'App\\Events\\MessageSent':
        final msg = Message.fromJson(event.data);
        notifier.applyRealtime(msg);

        // If user is not currently inside this conversation, show an in-app banner
        final currentUserId = _ref.read(authProvider).user?.id;
        if (conversationId != _activeConversationId && msg.userId != currentUserId) {
          _ref.read(inAppNotificationProvider.notifier).showFromMessage(msg);
        }
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
    _subscribedConversations.clear();
    _userId = null;
    _activeConversationId = null;
  }
}

final realtimeProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref);
  ref.onDispose(service.dispose);
  return service;
});
