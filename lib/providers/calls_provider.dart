import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'contactName': contactName,
        'phoneNumber': phoneNumber,
        'direction': direction.name,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'isVideo': isVideo,
        'avatarUrl': avatarUrl,
      };

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id']?.toString() ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
      contactName: json['contactName']?.toString() ?? 'Contact',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      direction: CallDirection.values.firstWhere(
        (d) => d.name == json['direction'],
        orElse: () => CallDirection.outgoing,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      isVideo: json['isVideo'] as bool? ?? false,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
    );
  }

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
  static const String _storageKey = 'murihspace_call_logs_v1';

  @override
  CallsState build() {
    _loadFromStorage();
    return CallsState(calls: []);
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => CallRecord.fromJson(j))
            .toList();
        state = state.copyWith(calls: list);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.calls.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
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
    String avatarUrl = '',
  }) {
    final newCall = CallRecord(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      contactName: contactName,
      phoneNumber: phoneNumber,
      direction: direction,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      isVideo: isVideo,
      avatarUrl: avatarUrl,
    );
    state = state.copyWith(calls: [newCall, ...state.calls]);
    _persist();
  }

  void deleteCall(String id) {
    state = state.copyWith(calls: state.calls.where((c) => c.id != id).toList());
    _persist();
  }

  void clearCallLog() {
    state = state.copyWith(calls: []);
    _persist();
  }
}

final callsProvider = NotifierProvider<CallsNotifier, CallsState>(CallsNotifier.new);
