import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/roles.dart';
import 'auth_provider.dart';

enum BroadcastType { securityAlert, transactionOtp, announcement, systemUpdate }

class BroadcastMessage {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final BroadcastType type;
  final bool isRead;
  final String? actionUrl;
  final String? otpCode;

  BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.actionUrl,
    this.otpCode,
  });

  IconData get icon {
    switch (type) {
      case BroadcastType.securityAlert:
        return Icons.security_rounded;
      case BroadcastType.transactionOtp:
        return Icons.sms_rounded;
      case BroadcastType.announcement:
        return Icons.campaign_rounded;
      case BroadcastType.systemUpdate:
        return Icons.system_update_rounded;
    }
  }

  Color get color {
    switch (type) {
      case BroadcastType.securityAlert:
        return const Color(0xFFFF3B30);
      case BroadcastType.transactionOtp:
        return const Color(0xFFFF9500);
      case BroadcastType.announcement:
        return const Color(0xFF007AFF);
      case BroadcastType.systemUpdate:
        return const Color(0xFF34C759);
    }
  }
}

class BroadcastState {
  final List<BroadcastMessage> messages;
  final int unreadCount;
  final bool isPinned;

  BroadcastState({
    required this.messages,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  BroadcastState copyWith({
    List<BroadcastMessage>? messages,
    int? unreadCount,
    bool? isPinned,
  }) {
    return BroadcastState(
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class BroadcastNotifier extends Notifier<BroadcastState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  BroadcastState build() {
    // Initial real system alerts based on active platform policies
    final initialMsgs = [
      BroadcastMessage(
        id: 'sys_kyc_alert',
        title: '🛡️ Escrow Payout & Verification Policy',
        body: 'Identity (KYC) verification is required before initiating wallet payouts and funds withdrawals. Account transfers are protected by MurihSpace Escrow.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        type: BroadcastType.securityAlert,
        isRead: false,
        actionUrl: '/kyc',
      ),
      BroadcastMessage(
        id: 'sys_community_conf',
        title: '🎥 Community Conference & Live Audio/Video Calls',
        body: 'Built-in Google Meet-style conference rooms and WhatsApp-style HD voice/video calling are active for verified Creators and Community members.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: BroadcastType.announcement,
        isRead: true,
        actionUrl: '/app/communities',
      ),
      BroadcastMessage(
        id: 'sys_market_policy',
        title: '🛍️ Role-Gated Business & Marketplace Tools',
        body: 'Marketplace browsing is free for all members! Vendor Mode unlocks physical goods inventory listing, and Creator Mode unlocks digital asset sales.',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        type: BroadcastType.systemUpdate,
        isRead: true,
        actionUrl: '/upgrade-account',
      ),
    ];

    final unread = initialMsgs.where((m) => !m.isRead).length;

    // Async sync with API backend /notifications
    Future.microtask(() => fetchBackendBroadcasts());

    return BroadcastState(
      messages: initialMsgs,
      unreadCount: unread,
      isPinned: false, // NOT pinned by default as requested!
    );
  }

  /// Syncs real notifications from backend endpoint `/notifications`
  Future<void> fetchBackendBroadcasts() async {
    try {
      final response = await _dio.get('/notifications');
      final payload = ApiClient.instance.unwrap(response);
      final paginator = payload is Map<String, dynamic> ? payload['data'] : payload;
      final rawList = paginator is Map<String, dynamic> ? paginator['data'] : paginator;

      if (rawList is List && rawList.isNotEmpty) {
        final List<BroadcastMessage> fetched = [];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final dataMap = item['data'] as Map<String, dynamic>? ?? {};
            final typeStr = (item['type'] as String? ?? '').toLowerCase();

            BroadcastType bType = BroadcastType.announcement;
            if (typeStr.contains('security') || typeStr.contains('kyc')) {
              bType = BroadcastType.securityAlert;
            } else if (typeStr.contains('otp') || typeStr.contains('auth')) {
              bType = BroadcastType.transactionOtp;
            } else if (typeStr.contains('system')) {
              bType = BroadcastType.systemUpdate;
            }

            final createdAtStr = item['created_at'] as String?;
            final date = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

            fetched.add(
              BroadcastMessage(
                id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: dataMap['title'] as String? ?? 'System Alert',
                body: dataMap['message'] as String? ?? dataMap['body'] as String? ?? 'Official platform notification.',
                timestamp: date,
                type: bType,
                isRead: item['read_at'] != null || item['read'] == true,
                actionUrl: dataMap['action_url'] as String?,
              ),
            );
          }
        }

        if (fetched.isNotEmpty) {
          // Merge with initial system messages
          final existingIds = state.messages.map((m) => m.id).toSet();
          final newItems = fetched.where((f) => !existingIds.contains(f.id)).toList();
          final combined = [...newItems, ...state.messages];
          combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final unreadCount = combined.where((m) => !m.isRead).length;

          state = state.copyWith(messages: combined, unreadCount: unreadCount);
        }
      }
    } catch (_) {
      // Retains state
    }
  }

  void togglePin() {
    state = state.copyWith(isPinned: !state.isPinned);
  }

  void markAllAsRead() {
    final updated = state.messages.map((m) {
      return BroadcastMessage(
        id: m.id,
        title: m.title,
        body: m.body,
        timestamp: m.timestamp,
        type: m.type,
        isRead: true,
        actionUrl: m.actionUrl,
        otpCode: m.otpCode,
      );
    }).toList();

    state = state.copyWith(messages: updated, unreadCount: 0);
  }

  void addBroadcastMessage(BroadcastMessage msg) {
    state = state.copyWith(
      messages: [msg, ...state.messages],
      unreadCount: state.unreadCount + 1,
    );
  }
}

final broadcastProvider = NotifierProvider<BroadcastNotifier, BroadcastState>(BroadcastNotifier.new);

