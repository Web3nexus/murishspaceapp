import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  BroadcastState({
    required this.messages,
    this.unreadCount = 0,
  });

  BroadcastState copyWith({
    List<BroadcastMessage>? messages,
    int? unreadCount,
  }) {
    return BroadcastState(
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class BroadcastNotifier extends Notifier<BroadcastState> {
  @override
  BroadcastState build() {
    return BroadcastState(
      unreadCount: 2,
      messages: [
        BroadcastMessage(
          id: 'b_sec_1',
          title: '⚠️ Unusual IP Login Alert',
          body: 'A new login attempt was detected from Frankfurt, Germany (IP: 185.220.101.5). If this wasn\'t you, tap to terminate session immediately.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          type: BroadcastType.securityAlert,
          isRead: false,
          actionUrl: '/profile/devices',
        ),
        BroadcastMessage(
          id: 'b_otp_1',
          title: '💬 Transaction OTP Verification Code',
          body: 'Your MurihSpace wallet authorization code is 849201. Sent via SMS to your registered phone number (+234 812 *** 4567). Valid for 10 minutes.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
          type: BroadcastType.transactionOtp,
          otpCode: '849201',
          isRead: false,
        ),
        BroadcastMessage(
          id: 'b_ann_1',
          title: '🚀 Community Guidelines & Brand Deals Fee Update',
          body: 'Platform commitment deposit rules (30% minimum deposit) and Digital Escrow Contract Certificates are now active for all Brand Ambassador deals!',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          type: BroadcastType.announcement,
          isRead: true,
          actionUrl: '/brand-deals',
        ),
      ],
    );
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
