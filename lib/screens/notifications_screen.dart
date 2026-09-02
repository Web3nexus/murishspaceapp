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
                    final route = notification.route;
                    final conversationId = notification.conversationId;
                    if (route != null && route.isNotEmpty) {
                      context.push(route);
                    } else if (conversationId != null) {
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
    final isOfficial = notification.isOfficial;
    final isVerified = notification.isVerified;
    final unread = !notification.read;
    final type = notification.notificationType ?? notification.type;

    // Resolve icon & accent color
    IconData icon = Icons.notifications_rounded;
    Color accentColor = const Color(0xFF007AFF);

    if (type.contains('role_upgrade_approved') || type.contains('creator') || type.contains('vendor')) {
      icon = Icons.workspace_premium_rounded;
      accentColor = const Color(0xFFFF9500);
    } else if (type.contains('kyc_approved') || type.contains('verified')) {
      icon = Icons.verified_user_rounded;
      accentColor = const Color(0xFF34C759);
    } else if (type.contains('kyc_requested') || type.contains('kyc')) {
      icon = Icons.shield_rounded;
      accentColor = const Color(0xFF007AFF);
    } else if (type.contains('gift')) {
      icon = Icons.card_giftcard_rounded;
      accentColor = const Color(0xFFFF2D55);
    } else if (type.contains('money') || type.contains('transfer') || type.contains('donation') || type.contains('wallet')) {
      icon = Icons.account_balance_wallet_rounded;
      accentColor = const Color(0xFF10B981);
    } else if (type.contains('message') || type.contains('chat')) {
      icon = Icons.chat_bubble_rounded;
      accentColor = const Color(0xFF007AFF);
    }

    final channelName = isOfficial ? 'Murih Notifications Official' : (notification.senderName ?? 'Notification');
    final title = notification.title;
    final body = notification.body;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: unread ? (isDark ? const Color(0xFF2C2C2E).withOpacity(0.5) : const Color(0xFF007AFF).withOpacity(0.04)) : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading Badge / Avatar Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender / Channel Name + Blue Badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channelName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isOfficial ? const Color(0xFF007AFF) : (isDark ? Colors.grey[300] : Colors.grey[800]),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFF007AFF),
                        ),
                      ],
                      if (notification.createdAt != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${_formatTimeAgo(notification.createdAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  if (title.isNotEmpty && title != channelName)
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),

                  const SizedBox(height: 2),

                  // Body
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
