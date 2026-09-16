import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../services/sound_service.dart';
import 'auth_provider.dart';

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

class ActiveCallSession {
  final int callId;
  final String roomName;
  final String? token;
  final String? host;
  final int callerId;
  final String callerName;
  final String callerAvatar;
  final int recipientId;
  final String recipientName;
  final String callType; // 'audio' or 'video'
  final String status; // 'incoming', 'ringing', 'connected', 'declined', 'ended'
  final bool isIncoming;
  final int? conversationId;
  final DateTime? startedAt;

  ActiveCallSession({
    required this.callId,
    required this.roomName,
    this.token,
    this.host,
    required this.callerId,
    required this.callerName,
    this.callerAvatar = '',
    required this.recipientId,
    this.recipientName = '',
    this.callType = 'audio',
    this.status = 'ringing',
    this.isIncoming = false,
    this.conversationId,
    this.startedAt,
  });

  ActiveCallSession copyWith({
    int? callId,
    String? roomName,
    String? token,
    String? host,
    int? callerId,
    String? callerName,
    String? callerAvatar,
    int? recipientId,
    String? recipientName,
    String? callType,
    String? status,
    bool? isIncoming,
    int? conversationId,
    DateTime? startedAt,
  }) {
    return ActiveCallSession(
      callId: callId ?? this.callId,
      roomName: roomName ?? this.roomName,
      token: token ?? this.token,
      host: host ?? this.host,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      isIncoming: isIncoming ?? this.isIncoming,
      conversationId: conversationId ?? this.conversationId,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class CallsState {
  final List<CallRecord> calls;
  final String filter; // 'all' or 'missed'
  final ActiveCallSession? activeCall;

  CallsState({
    required this.calls,
    this.filter = 'all',
    this.activeCall,
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
    ActiveCallSession? activeCall,
    bool clearActiveCall = false,
  }) {
    return CallsState(
      calls: calls ?? this.calls,
      filter: filter ?? this.filter,
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
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

  Future<Map<String, dynamic>?> initiateCall({
    required int recipientId,
    required String type,
    int? conversationId,
    required String contactName,
    String? avatarUrl,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post('/calls/initiate', data: {
        'recipient_id': recipientId,
        'type': type,
        'conversation_id': ?conversationId,
      });
      final unwrapped = ApiClient.instance.unwrap(res);
      final data = unwrapped is Map<String, dynamic> ? unwrapped : <String, dynamic>{};
      final callData = data['call'] is Map<String, dynamic> ? data['call'] as Map<String, dynamic> : data;
      final callId = (callData['id'] as num?)?.toInt() ?? 0;
      final roomName = (data['room_name'] ?? callData['room_name'])?.toString() ?? 'call_$callId';
      final token = (data['livekit_token'] ?? data['token'])?.toString();
      final host = (data['livekit_host'] ?? data['host'])?.toString();

      final active = ActiveCallSession(
        callId: callId,
        roomName: roomName,
        token: token,
        host: host,
        callerId: ref.read(authProvider).user?.id ?? 0,
        callerName: ref.read(authProvider).user?.name ?? 'Me',
        callerAvatar: avatarUrl ?? '',
        recipientId: recipientId,
        recipientName: contactName,
        callType: type,
        status: 'connecting',
        isIncoming: false,
        conversationId: conversationId,
      );

      state = state.copyWith(activeCall: active);
      return data;
    } catch (e) {
      debugPrint('Error initiating call: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptCall(int callId) async {
    try {
      final res = await ApiClient.instance.dio.post('/calls/$callId/accept');
      final unwrapped = ApiClient.instance.unwrap(res);
      final data = unwrapped is Map<String, dynamic> ? unwrapped : <String, dynamic>{};
      final token = (data['livekit_token'] ?? data['token'])?.toString();
      final host = (data['livekit_host'] ?? data['host'])?.toString();
      if (state.activeCall != null) {
        state = state.copyWith(
          activeCall: state.activeCall!.copyWith(
            status: 'connected',
            token: token ?? state.activeCall!.token,
            host: host ?? state.activeCall!.host,
          ),
        );
      }
      return data;
    } catch (e) {
      debugPrint('Error accepting call: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCallToken(int callId) async {
    try {
      final res = await ApiClient.instance.dio.get('/calls/$callId/token');
      final unwrapped = ApiClient.instance.unwrap(res);
      final data = unwrapped is Map<String, dynamic> ? unwrapped : <String, dynamic>{};
      final token = (data['livekit_token'] ?? data['token'])?.toString();
      final host = (data['livekit_host'] ?? data['host'])?.toString();
      if (state.activeCall != null) {
        state = state.copyWith(
          activeCall: state.activeCall!.copyWith(
            token: token ?? state.activeCall!.token,
            host: host ?? state.activeCall!.host,
          ),
        );
      }
      return data;
    } catch (e) {
      debugPrint('Error fetching call token: $e');
      return null;
    }
  }

  Future<void> declineCall(int callId) async {
    try {
      await ApiClient.instance.dio.post('/calls/$callId/decline');
    } catch (_) {}
    if (state.activeCall?.callId == callId) {
      logNewCall(
        contactName: state.activeCall?.callerName ?? 'Contact',
        phoneNumber: '',
        direction: CallDirection.missed,
        durationSeconds: 0,
        isVideo: state.activeCall?.callType == 'video',
        avatarUrl: state.activeCall?.callerAvatar ?? '',
      );
      state = state.copyWith(clearActiveCall: true);
    }
  }

  Future<void> endCall(int callId, {int durationSeconds = 0}) async {
    try {
      await ApiClient.instance.dio.post('/calls/$callId/end');
    } catch (_) {}
    if (state.activeCall != null) {
      logNewCall(
        contactName: state.activeCall!.isIncoming ? state.activeCall!.callerName : state.activeCall!.recipientName,
        phoneNumber: '',
        direction: state.activeCall!.isIncoming ? CallDirection.incoming : CallDirection.outgoing,
        durationSeconds: durationSeconds,
        isVideo: state.activeCall!.callType == 'video',
        avatarUrl: state.activeCall!.callerAvatar,
      );
      state = state.copyWith(clearActiveCall: true);
    }
  }

  void handleIncomingCall(Map<String, dynamic> data) {
    final callData = data['call'] is Map<String, dynamic> ? data['call'] as Map<String, dynamic> : data;
    final caller = data['caller'] is Map<String, dynamic>
        ? data['caller'] as Map<String, dynamic>
        : (callData['caller'] is Map<String, dynamic> ? callData['caller'] as Map<String, dynamic> : {});
    final callId = (callData['id'] as num?)?.toInt() ?? 0;
    if (callId <= 0) return;

    // Do not interrupt if already in this exact call session
    if (state.activeCall != null && state.activeCall!.callId == callId) return;

    final roomName = callData['room_name']?.toString() ?? '';
    final callerId = (callData['caller_id'] as num?)?.toInt() ?? 0;
    final callerName = (caller['name'] ?? callData['caller_name'] ?? caller['username'])?.toString() ?? 'Incoming Caller';
    final callerAvatar = (caller['avatar_url'] ?? caller['avatar'] ?? callData['caller_avatar'] ?? callData['avatar_url'])?.toString() ?? '';
    final callType = callData['type']?.toString() ?? 'audio';
    final token = (data['livekit_token'] ?? data['token'] ?? callData['livekit_token'])?.toString();
    final host = (data['livekit_host'] ?? data['host'] ?? callData['livekit_host'])?.toString();

    // Acknowledge receipt to backend immediately so caller knows recipient is ringing
    ApiClient.instance.dio.post('/calls/$callId/ringing').ignore();

    state = state.copyWith(
      activeCall: ActiveCallSession(
        callId: callId,
        roomName: roomName,
        token: token,
        host: host,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        recipientId: ref.read(authProvider).user?.id ?? 0,
        callType: callType,
        status: 'incoming',
        isIncoming: true,
        conversationId: (callData['conversation_id'] as num?)?.toInt(),
      ),
    );
  }

  void handleCallRinging(Map<String, dynamic> data) {
    if (state.activeCall != null && state.activeCall!.status == 'connecting') {
      state = state.copyWith(
        activeCall: state.activeCall!.copyWith(status: 'ringing'),
      );
    }
  }

  void handleCallAccepted(Map<String, dynamic> data) {
    if (state.activeCall != null) {
      final token = (data['livekit_token'] ?? data['token'])?.toString();
      final host = (data['livekit_host'] ?? data['host'])?.toString();
      final startedAtStr = (data['started_at'] ?? data['call']?['started_at'])?.toString();
      final startedAt = startedAtStr != null && startedAtStr.isNotEmpty
          ? DateTime.tryParse(startedAtStr)
          : null;
      state = state.copyWith(
        activeCall: state.activeCall!.copyWith(
          status: 'connected',
          token: state.activeCall!.isIncoming ? state.activeCall!.token : (token ?? state.activeCall!.token),
          host: host ?? state.activeCall!.host,
          startedAt: startedAt ?? state.activeCall!.startedAt ?? DateTime.now().toUtc(),
        ),
      );
    }
  }

  void handleCallDeclined(Map<String, dynamic> data) {
    SoundService.instance.stopRinging();
    if (state.activeCall != null) {
      state = state.copyWith(
        activeCall: state.activeCall!.copyWith(status: 'declined'),
      );
    }
  }

  void handleCallEnded(Map<String, dynamic> data) {
    SoundService.instance.stopRinging();
    state = state.copyWith(clearActiveCall: true);
  }
}

final callsProvider = NotifierProvider<CallsNotifier, CallsState>(CallsNotifier.new);
