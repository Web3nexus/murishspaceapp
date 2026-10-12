import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../config/router.dart';
import '../screens/live_stream_screen.dart';

/// Manages active live stream broadcast session state for in-app floating
/// Picture-in-Picture (PiP) mini-player and minimization.
class LiveSessionManager extends ChangeNotifier {
  static final LiveSessionManager instance = LiveSessionManager._();
  LiveSessionManager._();

  int? _activeStreamId;
  String? _trackingId;
  String _streamTitle = 'Live Broadcast';
  String _hostName = 'Host';
  String? _hostAvatarUrl;
  bool _isHost = false;
  String _streamMode = 'video';
  Room? _liveKitRoom;
  VideoTrack? _videoTrack;
  bool _isActive = false;
  bool _isMinimized = false;
  Offset _pipPosition = const Offset(16, 120);

  /// Optional teardown callback registered by active viewers when minimizing.
  Future<void> Function()? onTeardown;

  int? get activeStreamId => _activeStreamId;
  String? get trackingId => _trackingId;
  String get streamTitle => _streamTitle;
  String get hostName => _hostName;
  String? get hostAvatarUrl => _hostAvatarUrl;
  bool get isHost => _isHost;
  String get streamMode => _streamMode;
  Room? get liveKitRoom => _liveKitRoom;
  VideoTrack? get videoTrack => _videoTrack;
  bool get isActive => _isActive;
  bool get isMinimized => _isMinimized;
  Offset get pipPosition => _pipPosition;

  Future<void> startLiveSession({
    required int streamId,
    String? trackingId,
    required String streamTitle,
    required String hostName,
    String? hostAvatarUrl,
    required bool isHost,
    String streamMode = 'video',
    Room? room,
    VideoTrack? videoTrack,
  }) async {
    if (_isActive && _activeStreamId != streamId) {
      await closeLive();
    }
    _activeStreamId = streamId;
    _trackingId = trackingId;
    _streamTitle = streamTitle;
    _hostName = hostName;
    _hostAvatarUrl = hostAvatarUrl;
    _isHost = isHost;
    _streamMode = streamMode;
    _liveKitRoom = room;
    _videoTrack = videoTrack;
    _isActive = true;
    _isMinimized = false;
    notifyListeners();
  }

  void updateVideoTrack(VideoTrack? track) {
    if (_videoTrack != track) {
      _videoTrack = track;
      notifyListeners();
    }
  }

  void updateRoom(Room? room) {
    _liveKitRoom = room;
  }

  void updatePipPosition(Offset newPos) {
    _pipPosition = newPos;
    notifyListeners();
  }

  void setMinimized(bool minimized) {
    if (_isMinimized != minimized) {
      _isMinimized = minimized;
      notifyListeners();
    }
  }

  void minimizeLive([BuildContext? context]) {
    if (!_isActive) return;
    _isMinimized = true;
    notifyListeners();

    if (context != null) {
      try {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }
      } catch (_) {}
    }

    try {
      final rootNav = rootNavigatorKey.currentState;
      if (rootNav != null && rootNav.canPop()) {
        rootNav.pop();
        return;
      }
    } catch (_) {}

    try {
      if (context != null) {
        context.go('/app/home');
      }
    } catch (_) {}
  }

  void restoreLive(BuildContext context) {
    _isMinimized = false;
    onTeardown = null;
    notifyListeners();

    if (_activeStreamId == null && _trackingId == null) return;

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          streamId: _activeStreamId,
          trackingId: _trackingId,
          streamTitle: _streamTitle,
          hostName: _hostName,
          isHost: _isHost,
          streamMode: _streamMode,
        ),
      ),
    );
  }

  Future<void> closeLive() async {
    _isActive = false;
    _isMinimized = false;
    _activeStreamId = null;
    _trackingId = null;
    _videoTrack = null;

    final teardown = onTeardown;
    onTeardown = null;
    if (teardown != null) {
      try {
        await teardown();
      } catch (_) {}
    }

    final room = _liveKitRoom;
    _liveKitRoom = null;
    if (room != null) {
      try {
        await room.disconnect();
        await room.dispose();
      } catch (_) {}
    }

    notifyListeners();
  }
}

