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
    // Zero hardcoded messages - dynamic backend broadcasts only
    Future.microtask(() => fetchBackendBroadcasts());

    return BroadcastState(
      messages: const [],
      unreadCount: 0,
      isPinned: false,
    );
  }

  /// Syncs real announcements and security alerts from `/system-broadcasts` and `/notifications`
  Future<void> fetchBackendBroadcasts() async {
    final List<BroadcastMessage> fetched = [];

    // 1. Fetch official system broadcasts sent by administrators via CMS
    try {
      final bResponse = await _dio.get('/system-broadcasts');
      final bPayload = ApiClient.instance.unwrap(bResponse);
      final bPaginator = bPayload is Map<String, dynamic> ? bPayload['data'] : bPayload;
      final bList = bPaginator is Map<String, dynamic> ? bPaginator['data'] : bPaginator;

      if (bList is List) {
        for (final item in bList) {
          if (item is Map<String, dynamic>) {
            final typeStr = (item['type'] as String? ?? '').toLowerCase();
            BroadcastType bType = BroadcastType.announcement;
            if (typeStr.contains('security')) {
              bType = BroadcastType.securityAlert;
            } else if (typeStr.contains('system')) {
              bType = BroadcastType.systemUpdate;
            }

            final createdAtStr = item['sent_at'] as String? ?? item['created_at'] as String?;
            final date = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

            fetched.add(
              BroadcastMessage(
                id: 'broadcast_${item['id']}',
                title: item['title'] as String? ?? 'Official Broadcast',
                body: item['body'] as String? ?? '',
                timestamp: date,
                type: bType,
                isRead: false,
                actionUrl: item['action_url'] as String?,
              ),
            );
          }
        }
      }
    } catch (_) {
      // system broadcasts fetch resilience
    }

    // 2. Fetch personal system/security notifications & device login codes
    try {
      final response = await _dio.get('/notifications');
      final payload = ApiClient.instance.unwrap(response);
      final paginator = payload is Map<String, dynamic> ? payload['data'] : payload;
      final rawList = paginator is Map<String, dynamic> ? paginator['data'] : paginator;

      if (rawList is List && rawList.isNotEmpty) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final dataMap = item['data'] as Map<String, dynamic>? ?? {};
            final typeStr = (item['type'] as String? ?? '').toLowerCase();
            final metaMap = dataMap['metadata'] as Map<String, dynamic>? ?? {};

            BroadcastType bType = BroadcastType.announcement;
            if (typeStr.contains('security') || typeStr.contains('kyc') || typeStr.contains('device')) {
              bType = BroadcastType.securityAlert;
            } else if (typeStr.contains('otp') || typeStr.contains('code') || dataMap.containsKey('code')) {
              bType = BroadcastType.transactionOtp;
            } else if (typeStr.contains('system')) {
              bType = BroadcastType.systemUpdate;
            }

            final code = dataMap['code']?.toString() ?? metaMap['code']?.toString();
            final createdAtStr = item['created_at'] as String?;
            final date = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

            fetched.add(
              BroadcastMessage(
                id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: dataMap['title'] as String? ?? (code != null ? '🔐 Login Verification Code' : 'System Alert'),
                body: dataMap['message'] as String? ?? dataMap['body'] as String? ?? 'Official platform notification.',
                timestamp: date,
                type: bType,
                isRead: item['read_at'] != null || item['read'] == true,
                actionUrl: dataMap['action_url'] as String?,
                otpCode: code,
              ),
            );
          }
        }
      }
    } catch (_) {
      // notifications fetch resilience
    }

    if (fetched.isNotEmpty) {
      final Map<String, BroadcastMessage> unique = {};
      for (final m in fetched) {
        unique[m.id] = m;
      }
      final list = unique.values.toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final unreadCount = list.where((m) => !m.isRead).length;

      state = state.copyWith(messages: list, unreadCount: unreadCount);
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

