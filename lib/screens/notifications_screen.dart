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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (state.unread > 0)
            TextButton(
              onPressed: () => notifier.markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _body(context, ref, state, notifier, isDark),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, NotificationsState state, NotificationsNotifier notifier, bool isDark) {
    if (state.loading && state.notifications.isEmpty) {
      return const LoadingStateWidget(message: 'Loading notifications…');
    }
    if (state.error != null && state.notifications.isEmpty) {
      return ErrorStateWidget(title: 'Could not load notifications', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.notifications.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        description: 'Message alerts and activity will show up here.',
      );
    }
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (_, i) {
                final notification = state.notifications[i];
                return _NotificationTile(
                  notification: notification,
                  isDark: isDark,
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
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final senderName = notification.senderName;
    final title = senderName != null ? '$senderName sent you a message' : 'New notification';
    final preview = notification.messagePreview ?? notification.notificationType ?? 'Activity update';
    final unread = !notification.read;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: unread ? const Color(0xFF007AFF) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mark_chat_unread_rounded,
          color: unread ? Colors.white : (isDark ? Colors.grey[400] : const Color(0xFF61758A)),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
