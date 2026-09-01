import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/chat_models.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'greeting_provider.dart';

/// State of a single conversation's message history.
class ConversationMessagesState {
  final List<Message> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  const ConversationMessagesState({
    this.messages = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
  });

  ConversationMessagesState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return ConversationMessagesState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConversationMessagesNotifier extends Notifier<ConversationMessagesState> {
  ConversationMessagesNotifier(this.conversationId);

  final int conversationId;
  int _page = 1;

  Dio get _dio => ApiClient.instance.dio;

  @override
  ConversationMessagesState build() {
    _load();
    return const ConversationMessagesState(loading: true);
  }

  Future<void> _load() async {
    _page = 1;
    try {
      final response = await _dio.get('/conversations/$conversationId/messages');
      final payload = ApiClient.instance.unwrap(response);
      final (list, hasMore) = _messagesFromPayload(payload);
      state = ConversationMessagesState(messages: list, hasMore: hasMore);
      await markRead();
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load messages.');
    }
  }

  Future<void> retry() => _load();

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    final nextPage = _page + 1;
    try {
      final response = await _dio.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'page': nextPage},
      );
      final payload = ApiClient.instance.unwrap(response);
      final (older, hasMore) = _messagesFromPayload(payload);
      _page = nextPage;
      state = ConversationMessagesState(
        messages: [...older, ...state.messages],
        hasMore: hasMore,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false, error: 'Failed to load older messages.');
    }
  }

  (List<Message>, bool) _messagesFromPayload(dynamic payload) {
    final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
    final list = rawList is List
        ? rawList.map(Message.fromJson).toList()
        : <Message>[];
    final hasMore = payload is Map<String, dynamic>
        ? (payload['next_page_url'] as String?) != null
        : false;
    return (list, hasMore);
  }

  /// Optimistically sends a text (or attached) message, then confirms via REST.
  /// Idempotent: the same [clientUuid] never double-posts.
  Future<void> sendMessage({
    required String content,
    int? replyToId,
    int? mediaId,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final auth = ref.read(authProvider);
    final me = auth.user;
    final clientUuid = ApiClient.generateIdempotencyKey();
    final optimistic = Message(
      id: 0,
      conversationId: conversationId,
      userId: me?.id ?? 0,
      content: content,
      type: attachmentType ?? 'text',
      status: 'sending',
      clientUuid: clientUuid,
      replyToId: replyToId,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      createdAt: DateTime.now(),
      user: ChatUser(
        id: me?.id ?? 0,
        name: me?.name ?? '',
        username: me?.username ?? '',
      ),
    );
    _appendOrReplace(optimistic);

    try {
      final response = await _dio.post(
        '/conversations/$conversationId/messages',
        data: {
          'content': content,
          'client_uuid': clientUuid,
          'reply_to_id': ?replyToId,
          'media_id': ?mediaId,
          'attachment_url': ?attachmentUrl,
          'attachment_type': ?attachmentType,
        },
      );
      final confirmed = Message.fromJson(ApiClient.instance.unwrap(response));
      _appendOrReplace(confirmed, byUuid: clientUuid);
      ref.read(conversationsProvider.notifier).applyMessage(confirmed, currentUserId: me?.id ?? 0);
    } on DioException {
      _markFailed(clientUuid);
    } on ApiException {
      _markFailed(clientUuid);
    } catch (_) {
      _markFailed(clientUuid);
    }
  }

  Future<void> retrySending(Message message) async {
    if (message.clientUuid == null) return;
    final failed = Message(
      id: 0,
      conversationId: conversationId,
      userId: message.userId,
      content: message.content,
      type: message.type,
      status: 'sending',
      clientUuid: message.clientUuid,
      replyToId: message.replyToId,
      attachmentUrl: message.attachmentUrl,
      attachmentType: message.attachmentType,
      createdAt: DateTime.now(),
      user: message.user,
    );
    _appendOrReplace(failed);
    await sendMessage(
      content: message.content,
      replyToId: message.replyToId,
      mediaId: null,
      attachmentUrl: message.attachmentUrl,
      attachmentType: message.attachmentType,
    );
  }

  Future<void> markRead() async {
    try {
      await _dio.post('/conversations/$conversationId/read');
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Throttled on the caller side; the backend broadcasts the event to others.
  Future<void> sendTyping(bool isTyping) async {
    try {
      await _dio.post('/conversations/$conversationId/typing', data: {'is_typing': isTyping});
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    final existing = state.messages;
    state = state.copyWith(
      messages: existing.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(reactions: _flipReaction(m.reactions, emoji));
      }).toList(),
    );
    try {
      final response = await _dio.post('/messages/$messageId/reactions', data: {'emoji': emoji});
      final payload = ApiClient.instance.unwrap(response);
      if (payload is Map<String, dynamic> && payload['reactions'] is List) {
        final summary = (payload['reactions'] as List).map(ReactionSummary.fromJson).toList();
        _applyReactions(messageId, summary);
      }
    } catch (_) {
      // Revert on failure.
      state = state.copyWith(messages: existing);
    }
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    final before = state.messages;
    state = state.copyWith(
      messages: before.where((m) => m.id != messageId).toList(),
    );
    try {
      await _dio.delete(
        '/conversations/$conversationId/messages/$messageId',
        queryParameters: {'mode': forEveryone ? 'everyone' : 'me'},
      );
    } catch (_) {
      state = state.copyWith(messages: before);
    }
  }

  // ── Real-time hooks ───────────────────────────────────────────

  /// Appends a message delivered by Reverb, deduping against id / client_uuid.
  void applyRealtime(Message message) {
    if (message.id <= 0 && message.clientUuid == null) return;
    _appendOrReplace(message);
    final me = ref.read(authProvider).user;
    ref.read(conversationsProvider.notifier).applyMessage(message, currentUserId: me?.id ?? 0);
    _checkTriggerAutoGreeting(message);
  }

  bool _hasAutoReplied = false;

  void _checkTriggerAutoGreeting(Message incomingMessage) {
    if (_hasAutoReplied) return;
    final me = ref.read(authProvider).user;
    if (me == null || incomingMessage.userId == me.id) return;

    final greeting = ref.read(greetingProvider);
    if (!greeting.isEnabled || greeting.message.trim().isEmpty) return;

    _hasAutoReplied = true;

    final hour = DateTime.now().hour;
    final timeStr = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');
    final senderName = incomingMessage.user?.name ?? 'there';

    final formattedMessage = greeting.message
        .replaceAll('{name}', senderName)
        .replaceAll('{time}', timeStr);

    Timer(Duration(seconds: greeting.delaySeconds > 0 ? greeting.delaySeconds : 1), () {
      sendMessage(content: formattedMessage);
    });
  }

  void applyRealtimeDeleted(int messageId) {
    state = state.copyWith(messages: state.messages.where((m) => m.id != messageId).toList());
  }

  void applyRealtimeReaction(int messageId, List<ReactionSummary> reactions) {
    _applyReactions(messageId, reactions);
  }

  // ── Internals ─────────────────────────────────────────────────

  void _appendOrReplace(Message message, {String? byUuid}) {
    final list = List<Message>.from(state.messages);
    final idxById = list.indexWhere((m) => m.id == message.id && message.id != 0);
    final idxByUuid = list.indexWhere((m) =>
        m.clientUuid != null && message.clientUuid != null && m.clientUuid == message.clientUuid);

    if (idxById >= 0) {
      list[idxById] = message;
    } else if (idxByUuid >= 0) {
      list[idxByUuid] = message;
    } else {
      list.add(message);
    }
    state = state.copyWith(messages: list, clearError: true);
  }

  void _markFailed(String clientUuid) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.clientUuid == clientUuid) return m.copyWith(status: 'failed');
        return m;
      }).toList(),
    );
  }

  void _applyReactions(int messageId, List<ReactionSummary> reactions) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(reactions: reactions);
      }).toList(),
    );
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load messages.';
    return 'Failed to load messages.';
  }

  static List<ReactionSummary> _flipReaction(List<ReactionSummary> current, String emoji) {
    final idx = current.indexWhere((r) => r.emoji == emoji);
    final next = List<ReactionSummary>.from(current);
    if (idx >= 0) {
      final r = next[idx];
      if (r.byMe) {
        if (r.count <= 1) {
          next.removeAt(idx);
        } else {
          next[idx] = ReactionSummary(emoji: r.emoji, count: r.count - 1, byMe: false, users: r.users);
        }
      } else {
        next[idx] = ReactionSummary(emoji: r.emoji, count: r.count + 1, byMe: true, users: r.users);
      }
    } else {
      next.add(ReactionSummary(emoji: emoji, count: 1, byMe: true, users: const []));
    }
    return next;
  }
}

final conversationMessagesProvider =
    NotifierProvider.family<ConversationMessagesNotifier, ConversationMessagesState, int>(
  ConversationMessagesNotifier.new,
);
