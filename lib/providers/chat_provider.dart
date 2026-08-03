import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/chat_models.dart';

/// State of the conversation list screen.
class ConversationsState {
  final bool loading;
  final String? error;
  final List<Conversation> conversations;

  const ConversationsState({
    this.loading = false,
    this.error,
    this.conversations = const [],
  });

  ConversationsState copyWith({
    bool? loading,
    String? error,
    List<Conversation>? conversations,
    bool clearError = false,
  }) {
    return ConversationsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      conversations: conversations ?? this.conversations,
    );
  }
}

class ConversationsNotifier extends Notifier<ConversationsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  ConversationsState build() {
    _load();
    return const ConversationsState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final response = await _dio.get('/conversations');
      final list = ApiClient.instance.unwrapList<Conversation>(
        response,
        Conversation.fromJson,
      );
      state = ConversationsState(conversations: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load conversations.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// Upserts a conversation into the list (used after starting a chat).
  void upsert(Conversation conversation) {
    final list = [conversation, ...state.conversations.where((c) => c.id != conversation.id)];
    list.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    state = state.copyWith(conversations: list, clearError: true);
  }

  /// Applies an incoming/outgoing message to the matching row (reorder + unread).
  void applyMessage(Message message, {required int currentUserId}) {
    final conversationId = message.conversationId;
    final list = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      final unread = message.userId == currentUserId ? 0 : c.unreadCount + 1;
      return Conversation(
        id: c.id,
        type: c.type,
        title: c.title,
        community: c.community,
        otherUser: c.otherUser,
        latestMessage: message,
        unreadCount: unread,
        updatedAt: message.createdAt ?? DateTime.now(),
      );
    }).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    state = state.copyWith(conversations: list, clearError: true);
  }

  void markRead(int conversationId, int currentUserId) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) =>
              c.id == conversationId ? Conversation(id: c.id, type: c.type, title: c.title, community: c.community, otherUser: c.otherUser, latestMessage: c.latestMessage, unreadCount: 0, updatedAt: c.updatedAt) : c)
          .toList(),
    );
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load conversations.';
    return 'Failed to load conversations.';
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(ConversationsNotifier.new);

/// One user currently typing inside a conversation.
class TypingInfo {
  final int userId;
  final String userName;
  final DateTime at;

  const TypingInfo(this.userId, this.userName, this.at);
}

/// Tracks typists per conversation: conversationId → (userId → info).
class TypingNotifier extends Notifier<Map<int, Map<int, TypingInfo>>> {
  @override
  Map<int, Map<int, TypingInfo>> build() {
    ref.onDispose(() => _timer?.cancel());
    return const {};
  }

  Timer? _timer;

  void setTyping(int conversationId, int userId, String userName) {
    final next = Map<int, Map<int, TypingInfo>>.from(state);
    final perConversation = Map<int, TypingInfo>.from(next[conversationId] ?? const {});
    perConversation[userId] = TypingInfo(userId, userName, DateTime.now());
    next[conversationId] = perConversation;
    state = next;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      final now = DateTime.now();
      final pruned = Map<int, Map<int, TypingInfo>>.from(state);
      for (final entry in pruned.entries) {
        final filtered = Map<int, TypingInfo>.from(entry.value)
          ..removeWhere((_, info) => now.difference(info.at) > const Duration(seconds: 3));
        if (filtered.isEmpty) {
          pruned.remove(entry.key);
        } else {
          pruned[entry.key] = filtered;
        }
      }
      state = pruned;
    });
  }

  void clearTyping(int conversationId, int userId) {
    final perConversation = state[conversationId];
    if (perConversation == null || !perConversation.containsKey(userId)) return;
    final next = Map<int, Map<int, TypingInfo>>.from(state);
    final filtered = Map<int, TypingInfo>.from(perConversation)..remove(userId);
    if (filtered.isEmpty) {
      next.remove(conversationId);
    } else {
      next[conversationId] = filtered;
    }
    state = next;
  }
}

final typingProvider = NotifierProvider<TypingNotifier, Map<int, Map<int, TypingInfo>>>(
  TypingNotifier.new,
);
