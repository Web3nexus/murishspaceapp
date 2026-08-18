import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CallDirection { incoming, outgoing, missed }

class CallRecord {
  final String id;
  final String contactName;
  final String phoneNumber;
  final CallDirection direction;
  final DateTime timestamp;
  final int durationSeconds;
  final bool isVideo;
  final String avatarUrl;

  CallRecord({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.direction,
    required this.timestamp,
    required this.durationSeconds,
    this.isVideo = false,
    this.avatarUrl = '',
  });

  String get formattedType {
    switch (direction) {
      case CallDirection.incoming:
        return 'Incoming (${durationSeconds > 0 ? '${durationSeconds ~/ 60}m ${durationSeconds % 60}s' : '0s'})';
      case CallDirection.outgoing:
        return 'Outgoing (${durationSeconds > 0 ? '${durationSeconds ~/ 60}m ${durationSeconds % 60}s' : '0s'})';
      case CallDirection.missed:
        return 'Missed Call';
    }
  }

  IconData get icon {
    switch (direction) {
      case CallDirection.incoming:
        return Icons.call_received_rounded;
      case CallDirection.outgoing:
        return Icons.call_made_rounded;
      case CallDirection.missed:
        return Icons.call_missed_rounded;
    }
  }

  Color get color {
    switch (direction) {
      case CallDirection.incoming:
        return Colors.green;
      case CallDirection.outgoing:
        return const Color(0xFF007AFF);
      case CallDirection.missed:
        return const Color(0xFFFF3B30);
    }
  }
}

class CallsState {
  final List<CallRecord> calls;
  final String filter; // 'all' or 'missed'

  CallsState({
    required this.calls,
    this.filter = 'all',
  });

  List<CallRecord> get filteredCalls {
    if (filter == 'missed') {
      return calls.where((c) => c.direction == CallDirection.missed).toList();
    }
    return calls;
  }

  CallsState copyWith({
    List<CallRecord>? calls,
    String? filter,
  }) {
    return CallsState(
      calls: calls ?? this.calls,
      filter: filter ?? this.filter,
    );
  }
}

class CallsNotifier extends Notifier<CallsState> {
  @override
  CallsState build() {
    return CallsState(
      calls: [
        CallRecord(
          id: 'call_1',
          contactName: 'Alice Freeman',
          phoneNumber: '+1 555 019 2834',
          direction: CallDirection.incoming,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
          durationSeconds: 145,
          isVideo: true,
        ),
        CallRecord(
          id: 'call_2',
          contactName: 'Bob Smith',
          phoneNumber: '+234 802 123 4567',
          direction: CallDirection.outgoing,
          timestamp: DateTime.now().subtract(const Duration(hours: 18)),
          durationSeconds: 310,
        ),
        CallRecord(
          id: 'call_3',
          contactName: 'Charlie Brown',
          phoneNumber: '+44 7700 900077',
          direction: CallDirection.missed,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          durationSeconds: 0,
        ),
        CallRecord(
          id: 'call_4',
          contactName: 'David Miller (Vendor)',
          phoneNumber: '+1 800 555 0199',
          direction: CallDirection.incoming,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          durationSeconds: 420,
        ),
      ],
    );
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  void logNewCall({
    required String contactName,
    required String phoneNumber,
    required CallDirection direction,
    required int durationSeconds,
    bool isVideo = false,
  }) {
    final newCall = CallRecord(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      contactName: contactName,
      phoneNumber: phoneNumber,
      direction: direction,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      isVideo: isVideo,
    );
    state = state.copyWith(calls: [newCall, ...state.calls]);
  }

  void deleteCall(String id) {
    state = state.copyWith(calls: state.calls.where((c) => c.id != id).toList());
  }

  void clearCallLog() {
    state = state.copyWith(calls: []);
  }
}

final callsProvider = NotifierProvider<CallsNotifier, CallsState>(CallsNotifier.new);
