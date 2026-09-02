import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_models.dart';
import '../providers/notifications_provider.dart';

class InAppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String? subtitle;
  final String? avatarUrl;
  final String? route;
  final IconData icon;
  final Color accentColor;
  final bool isOfficial;
  final bool isVerified;

  const InAppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.subtitle,
    this.avatarUrl,
    this.route,
    this.icon = Icons.notifications_active_rounded,
    this.accentColor = const Color(0xFF007AFF),
    this.isOfficial = false,
    this.isVerified = false,
  });
}

class InAppNotificationNotifier extends Notifier<InAppNotificationItem?> {
  Timer? _dismissTimer;

  @override
  InAppNotificationItem? build() {
    return null;
  }

  void show(InAppNotificationItem item) {
    _dismissTimer?.cancel();
    state = item;
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      dismiss();
    });
  }

  void showFromAppNotification(AppNotification notif) {
    String title = notif.title;
    String body = notif.body;
    String? route = notif.route;
    IconData icon = Icons.notifications_rounded;
    Color color = const Color(0xFF007AFF);
    final isOfficial = notif.isOfficial;
    final isVerified = notif.isVerified;

    final type = notif.notificationType ?? notif.type;

    if (type.contains('role_upgrade_approved') || type.contains('creator') || type.contains('vendor')) {
      icon = Icons.workspace_premium_rounded;
      color = const Color(0xFFFF9500);
      route = route ?? '/upgrade';
    } else if (type.contains('kyc_approved') || type.contains('verified')) {
      icon = Icons.verified_user_rounded;
      color = const Color(0xFF34C759);
      route = route ?? '/you';
    } else if (type.contains('kyc_requested') || type.contains('kyc')) {
      icon = Icons.shield_rounded;
      color = const Color(0xFF007AFF);
      route = route ?? '/kyc';
    } else if (type.contains('gift')) {
      icon = Icons.card_giftcard_rounded;
      color = const Color(0xFFFF2D55);
      route = route ?? '/wallet';
    } else if (type.contains('money') || type.contains('transfer') || type.contains('donation') || type.contains('wallet')) {
      icon = Icons.account_balance_wallet_rounded;
      color = const Color(0xFF10B981);
      route = route ?? '/wallet';
    } else if (type.contains('message') || type.contains('Message')) {
      icon = Icons.chat_bubble_rounded;
      color = const Color(0xFF3B82F6);
      final convId = notif.data['conversation_id'];
      if (convId != null) {
        route = '/chats/$convId';
      }
    } else if (type.contains('order') || type.contains('Order')) {
      icon = Icons.shopping_bag_rounded;
      color = const Color(0xFF10B981);
    } else if (type.contains('room') || type.contains('live')) {
      icon = Icons.mic_rounded;
      color = const Color(0xFF8B5CF6);
    }

    show(InAppNotificationItem(
      id: notif.id,
      title: title.isNotEmpty ? title : 'MurihSpace Notification',
      body: body,
      subtitle: isOfficial ? 'Murih Notifications Official' : notif.senderName,
      route: route,
      icon: icon,
      accentColor: color,
      isOfficial: isOfficial,
      isVerified: isVerified,
    ));
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }
}

final inAppNotificationProvider =
    NotifierProvider<InAppNotificationNotifier, InAppNotificationItem?>(
        InAppNotificationNotifier.new);

class InAppNotificationOverlay extends ConsumerWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref.watch(inAppNotificationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        if (notification != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Dismissible(
                key: ValueKey(notification.id),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  ref.read(inAppNotificationProvider.notifier).dismiss();
                },
                child: GestureDetector(
                  onTap: () {
                    final route = notification.route;
                    ref.read(inAppNotificationProvider.notifier).dismiss();
                    if (route != null && route.isNotEmpty) {
                      context.push(route);
                    } else {
                      context.push('/notifications');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: notification.accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            notification.icon,
                            color: notification.accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      notification.subtitle ?? notification.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: notification.isOfficial
                                            ? const Color(0xFF007AFF)
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                    ),
                                  ),
                                  if (notification.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notification.title != notification.subtitle ? notification.title : notification.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (notification.title != notification.subtitle) ...[
                                const SizedBox(height: 1),
                                Text(
                                  notification.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

