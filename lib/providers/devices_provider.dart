import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final DeviceSession currentDevice;
  final List<DeviceSession> otherSessions;
  final bool hasSuspiciousAlert;

  DevicesState({
    required this.currentDevice,
    required this.otherSessions,
    this.hasSuspiciousAlert = false,
  });

  List<DeviceSession> get suspiciousSessions =>
      otherSessions.where((s) => s.isSuspiciousIp).toList();

  DevicesState copyWith({
    DeviceSession? currentDevice,
    List<DeviceSession>? otherSessions,
    bool? hasSuspiciousAlert,
  }) {
    return DevicesState(
      currentDevice: currentDevice ?? this.currentDevice,
      otherSessions: otherSessions ?? this.otherSessions,
      hasSuspiciousAlert: hasSuspiciousAlert ?? this.hasSuspiciousAlert,
    );
  }
}

class DevicesNotifier extends Notifier<DevicesState> {
  @override
  DevicesState build() {
    return DevicesState(
      hasSuspiciousAlert: true,
      currentDevice: DeviceSession(
        id: 'dev_curr',
        deviceName: 'iPhone 15 Pro',
        deviceType: DeviceType.phone,
        osVersion: 'iOS 17.5',
        appVersion: 'MurihSpace Mobile v1.4.0',
        location: 'Lagos, Nigeria',
        ipAddress: '197.210.64.12',
        lastActive: DateTime.now(),
        isCurrentDevice: true,
      ),
      otherSessions: [
        DeviceSession(
          id: 'dev_unusual_web',
          deviceName: 'Chrome Web Client (macOS)',
          deviceType: DeviceType.web,
          osVersion: 'macOS 14.4',
          appVersion: 'MurihSpace Web App',
          location: 'Frankfurt, Germany',
          ipAddress: '185.220.101.5',
          lastActive: DateTime.now().subtract(const Duration(minutes: 5)),
          isSuspiciousIp: true,
          suspiciousReason: 'New login detected from unrecognized IP (Frankfurt, Germany)',
        ),
        DeviceSession(
          id: 'dev_mac',
          deviceName: 'MacBook Air (M2)',
          deviceType: DeviceType.web,
          osVersion: 'macOS 15.2',
          appVersion: 'MurihSpace Web Client',
          location: 'London, United Kingdom',
          ipAddress: '86.14.92.103',
          lastActive: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
      ],
    );
  }

  void terminateSession(String sessionId) {
    final updated = state.otherSessions.where((s) => s.id != sessionId).toList();
    state = state.copyWith(
      otherSessions: updated,
      hasSuspiciousAlert: updated.any((s) => s.isSuspiciousIp),
    );
  }

  void terminateAllOtherSessions() {
    state = state.copyWith(
      otherSessions: [],
      hasSuspiciousAlert: false,
    );
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
