import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/notification_models.dart';

void main() {
  group('AppNotification', () {
    test('parses a new-message notification', () {
      final notification = AppNotification.fromJson({
        'id': 'uuid-1',
        'type': 'App\\Notifications\\NewMessageNotification',
        'data': {
          'type': 'new_message',
          'conversation_id': 42,
          'message_preview': 'Hello there',
          'sender_id': 9,
          'sender_name': 'Ann',
          'sender_username': 'ann',
          'sender_avatar': 'http://x/a.png',
        },
        'read_at': null,
        'created_at': '2026-08-03T12:00:00Z',
      });
      expect(notification.id, 'uuid-1');
      expect(notification.read, false);
      expect(notification.senderName, 'Ann');
      expect(notification.messagePreview, 'Hello there');
      expect(notification.conversationId, 42);
      expect(notification.notificationType, 'new_message');
      expect(notification.createdAt, isNotNull);
    });

    test('marks a notification as read when read_at is present', () {
      final notification = AppNotification.fromJson({
        'id': 'uuid-2',
        'type': 'App\\Notifications\\NewMessageNotification',
        'data': {'type': 'new_message'},
        'read_at': '2026-08-03T12:05:00Z',
      });
      expect(notification.read, true);
    });

    test('falls back safely on empty payloads', () {
      final notification = AppNotification.fromJson(null);
      expect(notification.id, '');
      expect(notification.read, false);
      expect(notification.senderName, isNull);
    });
  });
}
