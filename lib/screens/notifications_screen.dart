import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../models/notification_models.dart';
import '../providers/notifications_provider.dart';

/// In-app notifications feed — message alerts with read/unread state.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (state.unread > 0)
            TextButton(
              onPressed: () => notifier.markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _body(context, ref, state, notifier),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, NotificationsState state, NotificationsNotifier notifier) {
    if (state.loading && state.notifications.isEmpty) {
      return const LoadingStateWidget(message: 'Loading notifications…');
    }
    if (state.error != null && state.notifications.isEmpty) {
      return ErrorStateWidget(title: 'Could not load notifications', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.notifications.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none,
        title: 'No notifications yet',
        description: 'Message alerts and activity will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.notifications.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final notification = state.notifications[i];
          return _NotificationTile(
            notification: notification,
            onTap: () {
              notifier.markRead(notification.id);
              final conversationId = notification.conversationId;
              if (conversationId != null) {
                context.push('/app/conversation/$conversationId');
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final senderName = notification.senderName;
    final title = senderName != null ? '$senderName sent you a message' : 'New notification';
    final preview = notification.messagePreview ?? notification.notificationType ?? 'Activity update';
    final unread = !notification.read;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: unread ? DesignTokens.primary : DesignTokens.primarySoft,
        child: Icon(
          Icons.mark_chat_unread_outlined,
          color: unread ? Colors.white : DesignTokens.primaryDark,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: DesignTokens.textSecondary),
      ),
      trailing: unread
          ? const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.circle, size: 10, color: DesignTokens.primary),
            )
          : null,
    );
  }
}
