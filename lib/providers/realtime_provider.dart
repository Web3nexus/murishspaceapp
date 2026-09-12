import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/gift_animation_overlay.dart';
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

      if (event.event == 'gift.received' || event.event.contains('GiftReceived') || event.event.contains('GiftSent')) {
        try {
          final giftName = data['gift_name']?.toString() ?? data['gift']?['name']?.toString() ?? 'Gift';
          final senderName = data['sender_name']?.toString() ?? data['sender']?['name']?.toString() ?? 'Someone';
          final coinPrice = (data['coin_price'] as num?)?.toInt() ?? (data['amount'] as num?)?.toInt() ?? 100;
          final animType = data['animation_type']?.toString() ??
              (coinPrice >= 1000 ? 'full_screen' : (coinPrice >= 400 ? 'premium' : 'standard'));

          _ref.read(giftAnimationProvider.notifier).play(
            GiftAnimationData(
              giftName: giftName,
              iconEmoji: data['icon']?.toString() ?? '🎁',
              iconUrl: data['icon_url']?.toString(),
              coinPrice: coinPrice,
              senderName: senderName,
              recipientName: 'You',
              animationType: animType,
            ),
          );
        } catch (_) {}
        return;
      }

      if (event.event == 'notification' ||
          event.event == '.notification' ||
          event.event.contains('NotificationBroadcast') ||
          event.event.contains('Notifications\\')) {
        try {
          final notif = AppNotification.fromJson(data);
          _ref.read(inAppNotificationProvider.notifier).showFromAppNotification(notif);
          _ref.read(notificationsProvider.notifier).refresh();
        } catch (_) {}
      }

      // Handle incoming MessageSent on user personal channel — this is what delivers
      // messages to recipients who are NOT currently inside the conversation screen.
      if (event.event == 'App\\Events\\MessageSent' || event.event.endsWith('.MessageSent')) {
        try {
          final msg = Message.fromJson(data['message'] ?? data);
          final convId = msg.conversationId;
          if (convId > 0) {
            // Push message into that conversation's state (creates provider lazily)
            _ref.read(conversationMessagesProvider(convId).notifier).applyRealtime(msg);
            // Refresh chat list so the last-message preview updates
            _ref.read(conversationsProvider.notifier).refresh();
            // Show banner if user is not actively viewing this conversation
            final currentUserId = _ref.read(authProvider).user?.id;
            if (convId != _activeConversationId && msg.userId != currentUserId) {
              _ref.read(inAppNotificationProvider.notifier).showFromMessage(msg);
            }
          }
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

        final currentUserId = _ref.read(authProvider).user?.id;

        // If incoming message is a gift, trigger celebration animation
        if (msg.userId != currentUserId &&
            (msg.type == 'gift' || msg.attachmentType == 'gift' || msg.content.startsWith('[GIFT]'))) {
          String giftName = 'Virtual Gift';
          String giftEmoji = '🎁';
          int coins = 100;
          String animType = 'standard';
          final text = msg.content;
          if (text.startsWith('[GIFT]') && text.contains('[/GIFT]')) {
            try {
              final jsonStr = text.substring('[GIFT]'.length, text.indexOf('[/GIFT]'));
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              giftName = map['name']?.toString() ?? giftName;
              giftEmoji = map['icon']?.toString() ?? giftEmoji;
              coins = (map['coins'] as num?)?.toInt() ?? coins;
              animType = map['animation_type']?.toString() ?? animType;
            } catch (_) {}
          }
          _ref.read(giftAnimationProvider.notifier).play(
            GiftAnimationData(
              giftName: giftName,
              iconEmoji: giftEmoji,
              coinPrice: coins,
              senderName: msg.user?.name ?? 'Friend',
              recipientName: 'You',
              animationType: animType,
            ),
          );
        }

        // If user is not currently inside this conversation, show an in-app banner
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
      case 'App\\Events\\MessageDelivered':
        final data = event.data is Map ? Map<String, dynamic>.from(event.data as Map) : <String, dynamic>{};
        final rawIds = data['message_ids'];
        final ids = rawIds is List ? rawIds.map<int>((e) => (e as num).toInt()).toList() : <int>[];
        if (ids.isNotEmpty) notifier.applyRealtimeDelivered(ids);
      case 'App\\Events\\MessageRead':
        final data = event.data is Map ? Map<String, dynamic>.from(event.data as Map) : <String, dynamic>{};
        final readerId = (data['reader_id'] as num?)?.toInt() ?? 0;
        if (readerId > 0) notifier.applyRealtimeRead(readerId);
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
