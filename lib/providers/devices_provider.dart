import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

enum DeviceType { phone, desktop, tablet, web }

class DeviceSession {
  final String id;
  final String deviceName;
  final DeviceType deviceType;
  final String osVersion;
  final String appVersion;
  final String location;
  final String ipAddress;
  final DateTime lastActive;
  final bool isCurrentDevice;
  final bool isSuspiciousIp;
  final String? suspiciousReason;

  DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.osVersion,
    required this.appVersion,
    required this.location,
    required this.ipAddress,
    required this.lastActive,
    this.isCurrentDevice = false,
    this.isSuspiciousIp = false,
    this.suspiciousReason,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    final platform = (json['platform'] as String? ?? 'phone').toLowerCase();
    DeviceType type = DeviceType.phone;
    if (platform.contains('web') || platform.contains('chrome') || platform.contains('safari')) {
      type = DeviceType.web;
    } else if (platform.contains('mac') || platform.contains('windows') || platform.contains('linux')) {
      type = DeviceType.desktop;
    } else if (platform.contains('pad') || platform.contains('tablet')) {
      type = DeviceType.tablet;
    }

    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name'] as String? ?? 'Unknown Device',
      deviceType: type,
      osVersion: json['platform'] as String? ?? 'Unknown OS',
      appVersion: json['client_version'] as String? ?? 'MurihSpace Mobile',
      location: json['location'] as String? ?? 'Unknown Location',
      ipAddress: json['ip'] as String? ?? 'Unknown IP',
      lastActive: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isCurrentDevice: json['is_current'] as bool? ?? false,
      isSuspiciousIp: json['is_suspicious'] as bool? ?? false,
      suspiciousReason: json['suspicious_reason'] as String?,
    );
  }

  IconData get icon {
    switch (deviceType) {
      case DeviceType.phone:
        return Icons.phone_iphone_rounded;
      case DeviceType.desktop:
        return Icons.desktop_windows_rounded;
      case DeviceType.tablet:
        return Icons.tablet_mac_rounded;
      case DeviceType.web:
        return Icons.laptop_mac_rounded;
    }
  }

  Color get color {
    if (isSuspiciousIp) return const Color(0xFFFF3B30);
    if (isCurrentDevice) return const Color(0xFFFF9500);
    switch (deviceType) {
      case DeviceType.phone:
        return const Color(0xFF34C759);
      case DeviceType.desktop:
        return const Color(0xFF007AFF);
      case DeviceType.tablet:
        return const Color(0xFFAF52DE);
      case DeviceType.web:
        return const Color(0xFF5856D6);
    }
  }
}

class DevicesState {
  final DeviceSession? currentDevice;
  final List<DeviceSession> otherSessions;
  final bool hasSuspiciousAlert;
  final bool isLoading;

  DevicesState({
    this.currentDevice,
    required this.otherSessions,
    this.hasSuspiciousAlert = false,
    this.isLoading = false,
  });

  List<DeviceSession> get suspiciousSessions =>
      otherSessions.where((s) => s.isSuspiciousIp).toList();

  DevicesState copyWith({
    DeviceSession? currentDevice,
    List<DeviceSession>? otherSessions,
    bool? hasSuspiciousAlert,
    bool? isLoading,
  }) {
    return DevicesState(
      currentDevice: currentDevice ?? this.currentDevice,
      otherSessions: otherSessions ?? this.otherSessions,
      hasSuspiciousAlert: hasSuspiciousAlert ?? this.hasSuspiciousAlert,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DevicesNotifier extends Notifier<DevicesState> {
  @override
  DevicesState build() {
    Future.microtask(() => loadSessions());
    return DevicesState(
      otherSessions: [],
      isLoading: true,
    );
  }

  Future<void> loadSessions() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/auth/sessions');
      final list = (res.data['data'] ?? res.data) as List?;

      if (list != null) {
        DeviceSession? current;
        final List<DeviceSession> others = [];

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final session = DeviceSession.fromJson(item);
            if (session.isCurrentDevice && current == null) {
              current = session;
            } else {
              others.add(session);
            }
          }
        }

        current ??= DeviceSession(
          id: 'dev_curr',
          deviceName: 'Current Device',
          deviceType: DeviceType.phone,
          osVersion: 'Mobile',
          appVersion: 'MurihSpace',
          location: 'Current Session',
          ipAddress: '',
          lastActive: DateTime.now(),
          isCurrentDevice: true,
        );

        state = state.copyWith(
          currentDevice: current,
          otherSessions: others,
          hasSuspiciousAlert: others.any((s) => s.isSuspiciousIp),
          isLoading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> terminateSession(String sessionId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/auth/sessions/$sessionId');

      final updated = state.otherSessions.where((s) => s.id != sessionId).toList();
      state = state.copyWith(
        otherSessions: updated,
        hasSuspiciousAlert: updated.any((s) => s.isSuspiciousIp),
      );
    } catch (_) {}
  }

  Future<void> terminateAllOtherSessions() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/sessions/revoke-all-others');

      state = state.copyWith(
        otherSessions: [],
        hasSuspiciousAlert: false,
      );
    } catch (_) {}
  }

  void dismissAlert(String sessionId) {
    final updated = state.otherSessions.map((s) {
      if (s.id == sessionId) {
        return DeviceSession(
          id: s.id,
          deviceName: s.deviceName,
          deviceType: s.deviceType,
          osVersion: s.osVersion,
          appVersion: s.appVersion,
          location: s.location,
          ipAddress: s.ipAddress,
          lastActive: s.lastActive,
          isCurrentDevice: s.isCurrentDevice,
          isSuspiciousIp: false,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(
      otherSessions: updated,
      hasSuspiciousAlert: updated.any((s) => s.isSuspiciousIp),
    );
  }
}

final devicesProvider = NotifierProvider<DevicesNotifier, DevicesState>(DevicesNotifier.new);
