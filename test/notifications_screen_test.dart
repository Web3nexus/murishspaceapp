import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/notification_models.dart';
import 'package:mobile/providers/notifications_provider.dart';
import 'package:mobile/screens/notifications_screen.dart';

class _StubNotifications extends NotificationsNotifier {
  @override
  NotificationsState build() {
    return NotificationsState(
      loading: false,
      unread: 2,
      notifications: const [
        AppNotification(
          id: 'n1',
          type: 'App\\Notifications\\NewMessageNotification',
          data: {
            'type': 'new_message',
            'conversation_id': 42,
            'message_preview': 'Hi there',
            'sender_name': 'Ann',
          },
        ),
        AppNotification(
          id: 'n2',
          type: 'App\\Notifications\\NewMessageNotification',
          data: {
            'type': 'new_message',
            'conversation_id': 43,
            'message_preview': 'Welcome!',
            'sender_name': 'Bob',
          },
          read: true,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('renders notifications with unread indicator', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notificationsProvider.overrideWith(_StubNotifications.new)],
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pump();

    expect(find.text('Ann sent you a message'), findsOneWidget);
    expect(find.text('Bob sent you a message'), findsOneWidget);
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no notifications', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationsProvider.overrideWith(_EmptyNotifications.new),
      ],
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pump();

    expect(find.text('No notifications yet'), findsOneWidget);
  });
}

class _EmptyNotifications extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState();
}
