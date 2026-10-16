import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/router.dart';
import '../core/api_client.dart';
import '../screens/call_screen.dart';
import 'sound_service.dart';
import 'pip_service.dart';

enum CallStatus {
  idle,
  outgoing,
  ringing,
  connecting,
  connected,
  reconnecting,
  ending,
  ended,
  connectionFailed,
}

class CallReactionItem {
  final String id;
  final String emoji;
  final DateTime createdAt;

  CallReactionItem({
    required this.id,
    required this.emoji,
    required this.createdAt,
  });
}

/// Global Call Session Manager that preserves active call state, LiveKit WebRTC connection,
/// audio/video tracks, PiP minimization, and reactions across the entire application lifecycle.
class CallSessionManager extends ChangeNotifier {
  CallSessionManager._();
  static final CallSessionManager instance = CallSessionManager._();

  // Active LiveKit State
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _remoteVideoTrack;
  VideoTrack? _localVideoTrack;
  bool _isConnectingRoom = false;

  // Audio / Video control flags
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  bool _isScreenSharing = false;

  // View state
  bool _isSwapped = false; // Toggles between remote as main vs local as main
  bool _isMinimized = false; // Whether the call is in floating mini-window mode
  Offset _pipPosition = const Offset(16, 90); // Screen coordinates of floating PiP

  // Call Identity & Status
  CallStatus _status = CallStatus.idle;
  String? _statusMessage;
  int? _activeCallId;
  int? _recipientId;
  int? _conversationId;
  String _contactName = '';
  String? _avatarUrl;
  String? _phoneNumber;
  bool _isVideo = false;
  bool _isIncoming = false;
  bool _isAccepted = false;
  bool _hasEndedBackendCall = false;
  // Optional LiveKit credentials handed to us by the incoming-call push so the
  // callee can join the room immediately on answer (even from the OS CallKit UI)
  // without an extra HTTP round-trip.
  String? _pendingLivekitToken;
  String? _pendingLivekitHost;
  // Bumped whenever a session is torn down so in-flight async work (e.g. the
  // /calls/initiate response) can detect it no longer owns the session.
  int _sessionToken = 0;

  // Duration & Timers
  int _callSeconds = 0;
  DateTime? _startedAt;
  Timer? _callTimer;
  Timer? _statusPollTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _connectingTimeoutTimer;

  // Real-time emoji reactions
  final List<CallReactionItem> _activeReactions = [];

  // Getters
  Room? get room => _room;
  VideoTrack? get remoteVideoTrack => _remoteVideoTrack;
  VideoTrack? get localVideoTrack => _localVideoTrack;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;
  bool get isScreenSharing => _isScreenSharing;
  bool get isSwapped => _isSwapped;
  bool get isMinimized => _isMinimized;
  Offset get pipPosition => _pipPosition;
  CallStatus get status => _status;
  String? get statusMessage => _statusMessage;
  int? get activeCallId => _activeCallId;
  int? get recipientId => _recipientId;
  int? get conversationId => _conversationId;
  String get contactName => _contactName;
  String? get avatarUrl => _avatarUrl;
  String? get phoneNumber => _phoneNumber;
  bool get isVideo => _isVideo;
  bool get isIncoming => _isIncoming;
  bool get isAccepted => _isAccepted;
  int get callSeconds => _callSeconds;
  DateTime? get startedAt => _startedAt;
  List<CallReactionItem> get activeReactions => List.unmodifiable(_activeReactions);

  bool get isActive =>
      _status == CallStatus.outgoing ||
      _status == CallStatus.ringing ||
      _status == CallStatus.connecting ||
      _status == CallStatus.connected ||
      _status == CallStatus.reconnecting;

  bool get isConnected => _status == CallStatus.connected;

  /// Initializes or attaches to a call session.
  /// If the current call session is already active for this callId, it simply reattaches (e.g. restoring PiP).
  void initOrAttachCall({
    required String contactName,
    String? avatarUrl,
    String? phoneNumber,
    required bool isVideo,
    int? callId,
    bool isIncoming = false,
    bool isAccepted = false,
    int? recipientId,
    int? conversationId,
    String? livekitToken,
    String? livekitHost,
    VoidCallback? onInitiateFailed,
  }) {
    if (isActive) {
      // Only reattach when the call identity actually matches. A bare
      // `callId == null` short-circuit previously collapsed *any* newly
      // initiated call onto whatever was already active.
      final sameCall = callId != null && _activeCallId == callId;
      final sameRecipient =
          recipientId != null && _recipientId != null && _recipientId == recipientId;
      if (sameCall || sameRecipient) {
        _isMinimized = false;
        notifyListeners();
        return;
      }
    }

    // Clean up any stale session
    _cleanupSession(notify: false);

    _contactName = contactName;
    _avatarUrl = avatarUrl;
    _phoneNumber = phoneNumber;
    _isVideo = isVideo;
    _activeCallId = callId;
    _isIncoming = isIncoming;
    _isAccepted = isAccepted;
    _recipientId = recipientId;
    _conversationId = conversationId;
    _pendingLivekitToken = (livekitToken != null && livekitToken.isNotEmpty) ? livekitToken : null;
    _pendingLivekitHost = (livekitHost != null && livekitHost.isNotEmpty) ? livekitHost : null;
    _isCameraOff = !isVideo;
    _isSpeakerOn = isVideo;
    _isMuted = false;
    _isSwapped = false;
    _isMinimized = false;

    _requestPermissions().then((_) {
      if (_isVideo && _localVideoTrack == null && !_isCameraOff) {
        _initLocalCameraPreview();
      }
    });

    // Keep the screen awake for the whole duration of a call so the OS does not
    // sleep the display and tear down the WebRTC session (critical for video).
    _setWakelock(true);

    if (isIncoming) {
      if (isAccepted) {
        // Transitional CONNECTING state while LiveKit negotiates
        _status = CallStatus.connecting;
        _statusMessage = 'Connecting…';
        _callSeconds = 0;
        _connectLiveKit(overrideToken: _pendingLivekitToken, overrideHost: _pendingLivekitHost);
      } else {
        _status = CallStatus.ringing;
        _statusMessage = 'Incoming Call…';
        SoundService.instance.startIncomingRingtone();
        _startStatusPolling();
        _startRingingTimeout();
      }
    } else {
      // Outgoing call: starts in OUTGOING state
      _status = CallStatus.outgoing;
      _statusMessage = 'Calling $contactName…';
      _startRingingTimeout();
      SoundService.instance.startOutgoingRingback();

      if (_isVideo) {
        _initLocalCameraPreview();
      }

      if (_recipientId != null && _recipientId! > 0) {
        _startConnectingTimeout();
        _initiateBackendCall(onFailed: onInitiateFailed);
      }
    }

    notifyListeners();
  }

  Future<void> _initiateBackendCall({VoidCallback? onFailed}) async {
    // Snapshot the session this request belongs to. If the session is torn down
    // or replaced while the HTTP request is in flight, the response must not be
    // allowed to mutate the (now different) active call.
    final token = _sessionToken;
    final recipientId = _recipientId;
    final conversationId = _conversationId;
    final isVideo = _isVideo;
    try {
      final res = await ApiClient.instance.dio.post('/calls/initiate', data: {
        'recipient_id': recipientId,
        'type': isVideo ? 'video' : 'audio',
        'conversation_id': conversationId,
      });
      final unwrapped = ApiClient.instance.unwrap(res);
      final data = unwrapped is Map<String, dynamic> ? unwrapped : <String, dynamic>{};
      final callData = data['call'] is Map<String, dynamic> ? data['call'] as Map<String, dynamic> : data;
      final newCallId = (callData['id'] as num?)?.toInt();

      // Guard: If the user hung up, cancelled, or started another call while the
      // HTTP request was in flight, immediately terminate the orphaned backend
      // call so the other person does NOT keep ringing!
      if (token != _sessionToken || !isActive) {
        if (newCallId != null && newCallId > 0) {
          try {
            await ApiClient.instance.dio.post('/calls/$newCallId/end', data: {'duration': 0});
          } catch (_) {}
        }
        return;
      }

      _activeCallId = newCallId;
      _startStatusPolling();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallSessionManager] Error initiating call: $e');
      handleUnavailable(message: 'Contact is unavailable or offline');
      onFailed?.call();
    }
  }

  void _setWakelock(bool enabled) {
    try {
      if (enabled) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.microphone,
        if (_isVideo) Permission.camera,
      ].request();
    } catch (e) {
      debugPrint('[CallSessionManager] Error requesting permissions: $e');
    }
  }

  Future<void> _initLocalCameraPreview() async {
    try {
      final track = await LocalVideoTrack.createCameraTrack();
      _localVideoTrack = track;
      notifyListeners();
    } catch (e) {
      debugPrint('[CallSessionManager] Error creating local camera track: $e');
    }
  }

  void _startConnectingTimeout() {
    _connectingTimeoutTimer?.cancel();
    _connectingTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_status == CallStatus.outgoing || _status == CallStatus.connecting) {
        handleUnavailable(message: 'Contact is unavailable or offline');
      }
    });
  }

  void _startRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_status == CallStatus.ringing || _status == CallStatus.outgoing) {
        handleUnavailable(message: 'No answer');
      }
    });
  }

  void _scheduleCleanup(Duration delay) {
    final token = _sessionToken;
    Future.delayed(delay, () {
      if (token == _sessionToken) _cleanupSession();
    });
  }

  /// Handles the remote party accepting the call (real-time, no polling delay).
  void handleRemoteAccepted(Map<String, dynamic> data) {
    if (!isActive) return;
    final eventCallId = ((data['call_id'] ?? data['call']?['id'] ?? data['id']) as num?)?.toInt();
    if (eventCallId != null && _activeCallId != null && eventCallId != _activeCallId) {
      return;
    }

    // If this device was ringing with an incoming call, a remote accept means
    // the call was answered on another device. Stop ringing and finish locally.
    if (_isIncoming && _status == CallStatus.ringing) {
      SoundService.instance.stopRinging();
      _ringingTimeoutTimer?.cancel();
      _status = CallStatus.ended;
      _statusMessage = 'Answered on another device';
      notifyListeners();
      _scheduleCleanup(const Duration(milliseconds: 900));
      return;
    }

    if (_status == CallStatus.connected || _status == CallStatus.connecting) return;
    if (_status != CallStatus.outgoing && _status != CallStatus.ringing) return;
    final call = data['call'] is Map ? Map<String, dynamic>.from(data['call'] as Map) : data;
    final token = (data['livekit_token'] ?? data['token'] ?? call['livekit_token'])?.toString();
    final host = (data['livekit_host'] ?? data['host'] ?? call['livekit_host'])?.toString();
    final startedAtStr = (data['started_at'] ?? call['started_at'])?.toString();
    if (startedAtStr != null && startedAtStr.isNotEmpty) {
      _startedAt = DateTime.tryParse(startedAtStr);
    }
    SoundService.instance.stopRinging();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _status = CallStatus.connecting;
    _statusMessage = 'Connecting…';
    notifyListeners();
    _connectLiveKit(overrideToken: token, overrideHost: host);
  }

  /// Handles the remote party declining the call (real-time).
  void handleRemoteDeclined({Map<String, dynamic>? data, String message = 'Call declined'}) {
    if (_status == CallStatus.ended || _status == CallStatus.idle) return;
    if (data != null) {
      final eventCallId = ((data['call_id'] ?? data['call']?['id'] ?? data['id']) as num?)?.toInt();
      if (eventCallId != null && _activeCallId != null && eventCallId != _activeCallId) {
        return;
      }
    }
    SoundService.instance.stopRinging();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();
    _callTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    _status = CallStatus.ended;
    _statusMessage = message;
    notifyListeners();
    _scheduleCleanup(const Duration(milliseconds: 1400));
  }

  /// Handles the remote party ending the call (real-time). Tears the session
  /// down immediately on both ends instead of waiting for polling/timeouts.
  void handleRemoteEnded({Map<String, dynamic>? data, String message = 'Call ended'}) {
    if (_status == CallStatus.ended || _status == CallStatus.idle) return;
    if (data != null) {
      final eventCallId = ((data['call_id'] ?? data['call']?['id'] ?? data['id']) as num?)?.toInt();
      if (eventCallId != null && _activeCallId != null && eventCallId != _activeCallId) {
        return;
      }
    }
    SoundService.instance.stopRinging();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();
    _callTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    _status = CallStatus.ended;
    _statusMessage = message;
    notifyListeners();
    _scheduleCleanup(const Duration(milliseconds: 900));
  }

  void handleUnavailable({String message = 'Contact is unavailable or offline'}) {
    if (_status == CallStatus.connectionFailed || _status == CallStatus.ended) return;

    SoundService.instance.stopRinging();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();

    if (_activeCallId != null) {
      try {
        ApiClient.instance.dio.post('/calls/$_activeCallId/end', data: {'duration': 0});
      } catch (_) {}
    }

    _status = CallStatus.connectionFailed;
    _statusMessage = message;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (_status == CallStatus.connectionFailed) {
        _cleanupSession();
      }
    });
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_activeCallId == null) return;
      if (!isActive) {
        timer.cancel();
        return;
      }

      try {
        final res = await ApiClient.instance.dio.get('/calls/$_activeCallId');
        final data = ApiClient.instance.unwrap(res);
        if (data is! Map<String, dynamic>) return;
        final call = data['call'] is Map<String, dynamic> ? data['call'] as Map<String, dynamic> : data;
        final status = call['status']?.toString();

        if (status == 'ringing' && _status == CallStatus.outgoing) {
          _connectingTimeoutTimer?.cancel();
          _status = CallStatus.ringing;
          _statusMessage = 'Ringing…';
          SoundService.instance.startOutgoingRingback();
          notifyListeners();
        } else if (status == 'accepted' && _status != CallStatus.connected && _status != CallStatus.connecting) {
          _connectingTimeoutTimer?.cancel();
          await SoundService.instance.stopRinging();
          final token = _isIncoming ? null : (data['livekit_token'] ?? call['livekit_token'])?.toString();
          final host = (data['livekit_host'] ?? call['livekit_host'])?.toString();
          final startedAtStr = (data['started_at'] ?? call['started_at'])?.toString();
          if (startedAtStr != null && startedAtStr.isNotEmpty) {
            _startedAt = DateTime.tryParse(startedAtStr);
          }
          // Explicit CONNECTING state (never flash Disconnected)
          _status = CallStatus.connecting;
          _statusMessage = 'Connecting…';
          notifyListeners();
          _connectLiveKit(overrideToken: token, overrideHost: host);
        } else if (status == 'declined' && _status != CallStatus.ended) {
          timer.cancel();
          SoundService.instance.stopRinging();
          _status = CallStatus.ended;
          _statusMessage = 'Call declined';
          notifyListeners();
          Future.delayed(const Duration(milliseconds: 1400), () {
            _cleanupSession();
          });
        } else if (status == 'ended' && _status != CallStatus.ended) {
          if (_status == CallStatus.connected) {
            if (_room == null || _room!.remoteParticipants.isEmpty) {
              timer.cancel();
              _onRemoteParticipantLeft();
            }
          } else {
            timer.cancel();
            _onRemoteParticipantLeft();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _connectLiveKit({String? overrideToken, String? overrideHost}) async {
    if (_isConnectingRoom) return;
    if (_room != null && _room!.connectionState == ConnectionState.connected) {
      _status = CallStatus.connected;
      notifyListeners();
      return;
    }
    _isConnectingRoom = true;

    try {
      String? token = overrideToken;
      String? host = overrideHost;

      if ((token == null || token.isEmpty) && _activeCallId != null) {
        final res = await ApiClient.instance.dio.get('/calls/$_activeCallId/token');
        final data = ApiClient.instance.unwrap(res);
        if (data is Map<String, dynamic>) {
          token = (data['livekit_token'] ?? data['token'])?.toString();
          host = (data['livekit_host'] ?? data['host'])?.toString();
        }
      }

      if (token == null || token.isEmpty) {
        _isConnectingRoom = false;
        handleUnavailable(message: 'Could not connect call audio/video');
        return;
      }

      await Permission.microphone.request();

      var wsHost = host ?? 'wss://livekit.murihspace.com';
      if (!wsHost.startsWith('ws://') && !wsHost.startsWith('wss://')) {
        wsHost = 'wss://$wsHost';
      }

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            encoding: AudioEncoding.presetSpeech,
            dtx: true,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoCodec: 'VP8',
            simulcast: false,
          ),
        ),
      );

      _room = room;
      _listener = room.createListener();

      _listener!
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!event.isPlaying) {
            try {
              await _room?.startAudio();
            } catch (_) {}
          }
        })
        ..on<ParticipantConnectedEvent>((event) {
          notifyListeners();
        })
        ..on<TrackSubscribedEvent>((event) async {
          if (event.track is VideoTrack) {
            _remoteVideoTrack = event.track as VideoTrack;
          } else if (event.track is AudioTrack) {
            try {
              await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
            } catch (_) {}
          }
          notifyListeners();
        })
        ..on<TrackUnsubscribedEvent>((event) async {
          if (event.track is VideoTrack) {
            if (_remoteVideoTrack == event.track) _remoteVideoTrack = null;
          }
          notifyListeners();
        })
        ..on<DataReceivedEvent>((event) {
          try {
            final str = utf8.decode(event.data);
            final map = jsonDecode(str);
            if (map is Map && map['type'] == 'reaction' && map['emoji'] != null) {
              _triggerReaction(map['emoji'].toString(), broadcast: false);
            }
          } catch (_) {}
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          notifyListeners();
          Future.delayed(const Duration(milliseconds: 8000), () {
            if (_room?.remoteParticipants.isEmpty ?? true) {
              _onRemoteParticipantLeft();
            }
          });
        })
        ..on<ReconnectingEvent>((event) {
          if (_status == CallStatus.connected || _status == CallStatus.reconnecting) {
            _status = CallStatus.reconnecting;
            _statusMessage = 'Reconnecting…';
            notifyListeners();
          }
        })
        ..on<RoomReconnectedEvent>((event) {
          if (_status == CallStatus.reconnecting) {
            _status = CallStatus.connected;
            _statusMessage = 'Connected';
            notifyListeners();
          }
        })
        ..on<RoomDisconnectedEvent>((event) {
          // If disconnected during active call, transition to RECONNECTING (never flash Disconnected)
          if (_status == CallStatus.connected) {
            _status = CallStatus.reconnecting;
            _statusMessage = 'Reconnecting…';
            notifyListeners();
            Future.delayed(const Duration(milliseconds: 8000), () {
              if (_status == CallStatus.reconnecting && (_room == null || _room!.connectionState != ConnectionState.connected)) {
                _onRemoteParticipantLeft();
              }
            });
          }
        });

      await room.connect(wsHost, token);

      try {
        await room.startAudio();
      } catch (_) {}

      try {
        await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
      } catch (_) {}

      // Publish local mic
      await room.localParticipant?.setMicrophoneEnabled(!_isMuted);

      // Publish local camera if video call
      if (_isVideo) {
        if (_localVideoTrack is LocalVideoTrack) {
          await room.localParticipant?.publishVideoTrack(_localVideoTrack as LocalVideoTrack);
        } else {
          await room.localParticipant?.setCameraEnabled(!_isCameraOff);
          final pubs = room.localParticipant?.videoTrackPublications;
          if (pubs != null && pubs.isNotEmpty) {
            _localVideoTrack = pubs.first.track as VideoTrack?;
          }
        }
      }

      // Transition to CONNECTED state ONLY after LiveKit room is established
      _status = CallStatus.connected;
      _statusMessage = 'Connected';
      _isConnectingRoom = false;
      SoundService.instance.stopRinging();
      _ringingTimeoutTimer?.cancel();
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallSessionManager] Error connecting to LiveKit: $e');
      _isConnectingRoom = false;
      _status = CallStatus.connectionFailed;
      _statusMessage = 'Connection failed';
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_status == CallStatus.connectionFailed) {
          _cleanupSession();
        }
      });
    }
  }

  void _onRemoteParticipantLeft() {
    if (_room != null && _room!.remoteParticipants.isNotEmpty) {
      notifyListeners();
      return;
    }
    SoundService.instance.stopRinging();
    _ringingTimeoutTimer?.cancel();
    _callTimer?.cancel();
    _statusPollTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;

    _status = CallStatus.ended;
    _statusMessage = 'Call ended';
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1400), () {
      _cleanupSession();
    });
  }

  void _startDurationTimer() {
    _callTimer?.cancel();
    _updateCallSeconds();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == CallStatus.connected) {
        _updateCallSeconds();
      }
    });
  }

  void _updateCallSeconds() {
    if (_startedAt != null) {
      final diff = DateTime.now().toUtc().difference(_startedAt!.toUtc()).inSeconds;
      _callSeconds = diff > 0 ? diff : 0;
    } else {
      _callSeconds++;
    }
    notifyListeners();
  }

  // --- Controls ---

  Future<void> acceptCall() async {
    HapticFeedback.heavyImpact();
    await SoundService.instance.stopRinging();
    // Transition to CONNECTING state immediately (never flash Disconnected)
    _status = CallStatus.connecting;
    _statusMessage = 'Connecting…';
    notifyListeners();

    if (_activeCallId != null && _activeCallId! > 0) {
      try {
        final res = await ApiClient.instance.dio.post('/calls/$_activeCallId/accept');
        final unwrapped = ApiClient.instance.unwrap(res);
        final data = unwrapped is Map<String, dynamic> ? unwrapped : <String, dynamic>{};
        final call = data['call'] is Map ? data['call'] as Map : data;
        final startedAtStr = (call['started_at'] ?? data['started_at'])?.toString();
        if (startedAtStr != null && startedAtStr.isNotEmpty) {
          _startedAt = DateTime.tryParse(startedAtStr);
        }
      } catch (_) {}
    }

    _connectLiveKit(overrideToken: _pendingLivekitToken, overrideHost: _pendingLivekitHost);
  }

  void declineCall() {
    HapticFeedback.mediumImpact();
    SoundService.instance.stopRinging();
    if (_activeCallId != null && _activeCallId! > 0) {
      try {
        ApiClient.instance.dio.post('/calls/$_activeCallId/decline');
      } catch (_) {}
    }
    _status = CallStatus.ended;
    _statusMessage = 'Call declined';
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), () {
      _cleanupSession();
    });
  }

  void endCall() {
    if (_status == CallStatus.ended) return;

    HapticFeedback.mediumImpact();
    SoundService.instance.stopRinging();
    _callTimer?.cancel();
    _statusPollTimer?.cancel();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _listener?.dispose();
    _listener = null;

    final callIdToEnd = _activeCallId;
    if (!_hasEndedBackendCall && callIdToEnd != null && callIdToEnd > 0) {
      _hasEndedBackendCall = true;
      try {
        ApiClient.instance.dio.post('/calls/$callIdToEnd/end', data: {'duration': _callSeconds});
      } catch (_) {}
    }

    // Best-effort: end any phone-level CallKit call that the iOS fallback
    // provider reported (flutter_callkit_incoming can only end its own calls).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      const MethodChannel('murihspace/voip_fallback')
          .invokeMethod('endActive')
          .catchError((Object _) {});
    }

    _room?.disconnect();
    _room?.dispose();
    _room = null;

    _status = CallStatus.ended;
    _statusMessage = 'Call ended';
    _isMinimized = false;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 300), () {
      _cleanupSession();
    });
  }

  Future<void> toggleMute() async {
    HapticFeedback.selectionClick();
    _isMuted = !_isMuted;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    HapticFeedback.selectionClick();
    _isCameraOff = !_isCameraOff;
    try {
      await _room?.localParticipant?.setCameraEnabled(!_isCameraOff);
      if (!_isCameraOff && _localVideoTrack == null) {
        final pubs = _room?.localParticipant?.videoTrackPublications;
        if (pubs != null && pubs.isNotEmpty) {
          _localVideoTrack = pubs.first.track as VideoTrack?;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Upgrades an active audio call to a video call by enabling the camera and
  /// publishing the local video track mid-session.
  Future<void> switchToVideo() async {
    if (_isVideo) return;
    HapticFeedback.mediumImpact();
    _isVideo = true;
    _isCameraOff = false;
    _isSpeakerOn = true;
    notifyListeners();

    await _requestPermissions();

    try {
      if (_room != null && _room!.connectionState == ConnectionState.connected) {
        if (_localVideoTrack is LocalVideoTrack) {
          await _room!.localParticipant?.publishVideoTrack(_localVideoTrack as LocalVideoTrack);
        } else {
          await _room!.localParticipant?.setCameraEnabled(true);
          final pubs = _room!.localParticipant?.videoTrackPublications;
          if (pubs != null && pubs.isNotEmpty) {
            _localVideoTrack = pubs.first.track as VideoTrack?;
          }
        }
      } else {
        await _initLocalCameraPreview();
      }
    } catch (e) {
      debugPrint('[CallSessionManager] Error switching to video: $e');
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    HapticFeedback.selectionClick();
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> flipCamera() async {
    if (_room?.localParticipant == null) return;
    _isFrontCamera = !_isFrontCamera;
    final track = _room!.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track is LocalVideoTrack) {
      final options = track.currentOptions;
      if (options is CameraCaptureOptions) {
        try {
          await track.restartTrack(options.copyWith(
            cameraPosition: _isFrontCamera ? CameraPosition.front : CameraPosition.back,
          ));
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    HapticFeedback.mediumImpact();
    _isScreenSharing = !_isScreenSharing;
    try {
      await _room?.localParticipant?.setScreenShareEnabled(_isScreenSharing);
    } catch (_) {
      _isScreenSharing = false;
    }
    notifyListeners();
  }

  void swapVideos() {
    HapticFeedback.lightImpact();
    _isSwapped = !_isSwapped;
    notifyListeners();
  }

  void setMinimized(bool minimized) {
    if (_isMinimized != minimized) {
      _isMinimized = minimized;
      notifyListeners();
    }
  }

  void updatePipPosition(Offset newPos) {
    _pipPosition = newPos;
    notifyListeners();
  }

  void minimizeCall([BuildContext? context]) {
    if (!isActive) return;
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
      }
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    PipService.updateCallState(isActive: isActive, isVideo: _isVideo);
  }

  void restoreCall(BuildContext context) {
    _isMinimized = false;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rootNav = rootNavigatorKey.currentState;
      if (rootNav != null && rootNav.mounted) {
        rootNav.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              contactName: _contactName,
              avatarUrl: _avatarUrl,
              phoneNumber: _phoneNumber,
              isVideo: _isVideo,
              callId: _activeCallId,
              isIncoming: _isIncoming,
              isAccepted: _isAccepted,
              recipientId: _recipientId,
              conversationId: _conversationId,
            ),
          ),
        );
      }
    });
  }

  void sendReaction(String emoji) {
    _triggerReaction(emoji, broadcast: true);
  }

  void _triggerReaction(String emoji, {bool broadcast = true}) {
    final item = CallReactionItem(
      id: 'reaction_${DateTime.now().microsecondsSinceEpoch}',
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    _activeReactions.add(item);
    notifyListeners();

    // Auto-remove after animation completes
    Future.delayed(const Duration(milliseconds: 2400), () {
      _activeReactions.removeWhere((r) => r.id == item.id);
      notifyListeners();
    });

    if (broadcast && _room != null && _room!.connectionState == ConnectionState.connected) {
      try {
        final lp = _room!.localParticipant;
        if (lp != null) {
          final payload = jsonEncode({'type': 'reaction', 'emoji': emoji});
          lp.publishData(utf8.encode(payload), reliable: false).then<void>((_) {}, onError: (e) {
            debugPrint('[CallSessionManager] publishData reaction ignored error: $e');
          });
        }
      } catch (e) {
        debugPrint('[CallSessionManager] sendReaction ignored error: $e');
      }
    }
  }

  void _cleanupSession({bool notify = true}) {
    _sessionToken++;
    _setWakelock(false);
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();
    _callTimer?.cancel();
    SoundService.instance.stopRinging();

    _listener?.dispose();
    _listener = null;

    if (_localVideoTrack is LocalVideoTrack) {
      try {
        (_localVideoTrack as LocalVideoTrack).stop();
      } catch (_) {}
    }

    _room?.disconnect();
    _room?.dispose();
    _room = null;

    _localVideoTrack = null;
    _remoteVideoTrack = null;
    _status = CallStatus.idle;
    _isMinimized = false;
    _hasEndedBackendCall = false;
    _callSeconds = 0;
    _startedAt = null;
    _activeReactions.clear();

    if (notify) {
      notifyListeners();
    }
  }
}
