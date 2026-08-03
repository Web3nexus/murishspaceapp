import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/chat_models.dart';

void main() {
  group('ChatUser', () {
    test('parses avatar_url and avatar', () {
      final urlUser = ChatUser.fromJson({'id': 1, 'name': 'A', 'username': 'a', 'avatar_url': 'http://x/y.png'});
      expect(urlUser.avatarUrl, 'http://x/y.png');
      final avatarUser = ChatUser.fromJson({'id': 2, 'name': 'B', 'username': 'b', 'avatar': 'http://x/z.png'});
      expect(avatarUser.avatarUrl, 'http://x/z.png');
    });

    test('tolerates null', () {
      final user = ChatUser.fromJson(null);
      expect(user.id, 0);
      expect(user.name, '');
    });
  });

  group('Message', () {
    test('parses a REST payload', () {
      final message = Message.fromJson({
        'id': 42,
        'conversation_id': 7,
        'user_id': 3,
        'content': 'hello',
        'type': 'text',
        'status': 'sent',
        'client_uuid': 'abc',
        'created_at': '2026-08-03T12:00:00Z',
        'user': {'id': 3, 'name': 'Vincent', 'username': 'vincent', 'avatar_url': 'http://a.png'},
        'reactions': [
          {'emoji': '👍', 'count': 2, 'by_me': true, 'users': [1, 2]},
        ],
      });
      expect(message.id, 42);
      expect(message.conversationId, 7);
      expect(message.content, 'hello');
      expect(message.clientUuid, 'abc');
      expect(message.user?.name, 'Vincent');
      expect(message.reactions.single.emoji, '👍');
      expect(message.reactions.single.count, 2);
      expect(message.reactions.single.byMe, true);
      expect(message.createdAt, isNotNull);
    });

    test('parses a broadcast payload with nested reply_to', () {
      final message = Message.fromJson({
        'id': 9,
        'conversation_id': 7,
        'user_id': 3,
        'content': 'reply here',
        'type': 'text',
        'reply_to_id': 5,
        'reply_to': {
          'id': 5,
          'user_id': 1,
          'content': 'original',
          'user': {'id': 1, 'name': 'Original', 'username': 'orig'},
        },
      });
      expect(message.replyTo?.id, 5);
      expect(message.replyTo?.content, 'original');
      expect(message.replyTo?.user?.name, 'Original');
    });

    test('flags deleted and attachment types', () {
      final deleted = Message.fromJson({'id': 1, 'deleted': true});
      expect(deleted.deleted, true);
      final image = Message.fromJson({'id': 2, 'attachment_type': 'image', 'attachment_url': 'http://x'});
      expect(image.isImage, true);
      expect(image.hasAttachment, true);
      final voice = Message.fromJson({'id': 3, 'attachment_type': 'voice'});
      expect(voice.isVoice, true);
    });

    test('parses read receipt flag', () {
      expect(Message.fromJson({'id': 1, 'read': true}).read, true);
      expect(Message.fromJson({'id': 2}).read, false);
    });
  });

  group('Conversation', () {
    test('parses list item payload', () {
      final conversation = Conversation.fromJson({
        'id': 7,
        'type': 'direct',
        'title': 'Vincent Paul',
        'other_user': {'id': 3, 'name': 'Vincent Paul', 'username': 'vincent'},
        'latest_message': {'id': 1, 'content': 'hi', 'user_id': 3, 'conversation_id': 7},
        'unread_count': 3,
        'updated_at': '2026-08-03T12:00:00Z',
      });
      expect(conversation.id, 7);
      expect(conversation.type, 'direct');
      expect(conversation.otherUser?.name, 'Vincent Paul');
      expect(conversation.latestMessage?.content, 'hi');
      expect(conversation.unreadCount, 3);
      expect(conversation.updatedAt, isNotNull);
    });

    test('parses community chat metadata', () {
      final conversation = Conversation.fromJson({
        'id': 12,
        'type': 'community',
        'title': 'Murih Society',
        'community': {'id': 4, 'name': 'Murih Society', 'slug': 'murih'},
        'is_archived': true,
        'is_muted': true,
        'member_count': 42,
      });
      expect(conversation.type, 'community');
      expect(conversation.community?.name, 'Murih Society');
      expect(conversation.isArchived, true);
      expect(conversation.isMuted, true);
      expect(conversation.memberCount, 42);
      expect(conversation.avatarUrl, isNull);
    });

    test('copyWith preserves metadata fields', () {
      final conversation = Conversation(
        id: 12,
        type: 'community',
        title: 'Murih Society',
        isArchived: false,
        isMuted: true,
        memberCount: 7,
      );
      final archived = conversation.copyWith(isArchived: true, unreadCount: 0);
      expect(archived.isArchived, true);
      expect(archived.isMuted, true);
      expect(archived.memberCount, 7);
    });

    test('initials from title', () {
      expect(Conversation(id: 1, type: 'direct', title: 'John Doe').initials, 'JD');
      expect(Conversation(id: 2, type: 'direct', title: 'Alice').initials, 'A');
    });
  });
}
