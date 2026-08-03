import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/models/chat_models.dart';
import 'package:mobile/providers/chat_provider.dart';

void main() {
  group('ApiClient.unwrapList', () {
    test('unwraps envelope with plain array payload', () {
      final client = ApiClient.instance;
      final list = client.unwrapList<Conversation>(
        _fakeResponse({
          'success': true,
          'request_id': 'r1',
          'data': [
            {'id': 1, 'name': 'a'},
          ],
        }),
        Conversation.fromJson,
      );
      expect(list, hasLength(1));
      expect(list.first.id, 1);
    });

    test('tolerates paginated payload', () {
      final client = ApiClient.instance;
      final list = client.unwrapList<Conversation>(
        _fakeResponse({
          'success': true,
          'data': {
            'current_page': 1,
            'data': [
              {'id': 2, 'name': 'b'},
            ],
            'next_page_url': null,
          },
        }),
        Conversation.fromJson,
      );
      expect(list, hasLength(1));
      expect(list.first.id, 2);
    });

    test('returns empty for junk', () {
      final client = ApiClient.instance;
      expect(client.unwrapList<Conversation>(_fakeResponse({'success': true, 'data': 'nope'}), Conversation.fromJson), isEmpty);
    });
  });

  group('TypingNotifier', () {
    test('tracks and clears typists per conversation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(typingProvider.notifier);

      notifier.setTyping(5, 9, 'Ann');
      expect(container.read(typingProvider)[5]?[9]?.userName, 'Ann');

      notifier.clearTyping(5, 9);
      expect(container.read(typingProvider)[5], isNull);

      // Different conversation stays untouched.
      notifier.setTyping(6, 9, 'Ann');
      expect(container.read(typingProvider)[5], isNull);
      expect(container.read(typingProvider)[6]?[9], isNotNull);
    });
  });

  group('ConversationsNotifier.applyMessage', () {
    test('updates unread count and reorders', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      // Seed a conversation via upsert.
      notifier.upsert(const Conversation(id: 7, type: 'direct', title: 'Bob', updatedAt: null));
      notifier.applyMessage(
        Message(id: 1, conversationId: 7, userId: 9, content: 'hi', type: 'text', status: 'sent', createdAt: DateTime(2026, 8, 3)),
        currentUserId: 5,
      );

      final conv = container.read(conversationsProvider).conversations.first;
      expect(conv.unreadCount, 1);
      expect(conv.latestMessage?.content, 'hi');

      // A message from me resets unread.
      notifier.applyMessage(
        Message(id: 2, conversationId: 7, userId: 5, content: 'hey', type: 'text', status: 'sent'),
        currentUserId: 5,
      );
      expect(container.read(conversationsProvider).conversations.first.unreadCount, 0);
    });

    test('applyMessage and markRead preserve archive/mute metadata', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.upsert(const Conversation(
        id: 12,
        type: 'community',
        title: 'Murih Society',
        isArchived: true,
        isMuted: true,
        memberCount: 7,
        unreadCount: 3,
      ));

      notifier.applyMessage(
        Message(id: 9, conversationId: 12, userId: 9, content: 'hi', type: 'text', status: 'sent'),
        currentUserId: 5,
      );
      var conv = container.read(conversationsProvider).conversations.first;
      expect(conv.unreadCount, 4);
      expect(conv.isArchived, true);
      expect(conv.isMuted, true);
      expect(conv.memberCount, 7);

      notifier.markRead(12, 5);
      conv = container.read(conversationsProvider).conversations.first;
      expect(conv.unreadCount, 0);
      expect(conv.isArchived, true);
      expect(conv.isMuted, true);
      expect(conv.memberCount, 7);
    });
  });
}

Response<dynamic> _fakeResponse(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/test'),
    data: data,
    statusCode: 200,
  );
}
