import 'dart:async';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:permission_handler/permission_handler.dart';

import '../providers/calls_provider.dart';
import '../core/api_client.dart';
import '../services/sound_service.dart';

enum CallStatus {
  connecting,
  ringing,
  incoming, // full-screen incoming ringing (before accept/decline)
  connected,
  declined,
  unavailable,
  ended,
}

/// Real-Time Voice & Video Call Screen powered by LiveKit WebRTC SFU.
/// Handles WebRTC signaling, remote/local audio and video streams,
/// microphone mute, camera toggles, and duration tracking.
class CallScreen extends ConsumerStatefulWidget {
  final String contactName;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isVideo;
  final int? recipientId;
  final int? callId;
  final bool isIncoming;
  final bool isAccepted;

  CallScreen({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.avatarUrl,
    this.isVideo = false,
    this.recipientId,
    this.callId,
    this.isIncoming = false,
    this.isAccepted = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  late bool _isCameraOff;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  CallStatus _status = CallStatus.connecting;
  String? _statusMessage;
  int? _activeCallId;

  int _callSeconds = 0;
  DateTime? _startedAt;
  Timer? _callTimer;
  Timer? _statusPollTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _connectingTimeoutTimer;

  // LiveKit WebRTC state
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _remoteVideoTrack;
  VideoTrack? _localVideoTrack;
  bool _isConnectingRoom = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isCameraOff = !widget.isVideo;
    _isSpeakerOn = widget.isVideo;
    _activeCallId = widget.callId;

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _requestPermissions().then((_) {
      if (mounted && widget.isVideo && _localVideoTrack == null && !_isCameraOff) {
        _initLocalCameraPreview();
      }
    });

    if (widget.isIncoming) {
      if (widget.isAccepted) {
        _status = CallStatus.connected;
        _callSeconds = 0;
        _startDurationTimer();
        _connectLiveKit();
      } else {
        _status = CallStatus.incoming;
        SoundService.instance.startIncomingRingtone();
        _startStatusPolling();
        _startRingingTimeout();
      }
    } else {
      _status = CallStatus.connecting;
      _startRingingTimeout();
      SoundService.instance.startOutgoingRingback();

      if (widget.isVideo) {
        _initLocalCameraPreview();
      }

      // Initiate call on backend
      if (widget.recipientId != null && widget.recipientId! > 0) {
        _startConnectingTimeout();
        ref.read(callsProvider.notifier).initiateCall(
          recipientId: widget.recipientId!,
          type: widget.isVideo ? 'video' : 'audio',
          contactName: widget.contactName,
          avatarUrl: widget.avatarUrl,
        ).then((res) {
          if (!mounted) return;
          if (res != null) {
            final call = res['call'] is Map ? res['call'] : res;
            _activeCallId = (call['id'] as num?)?.toInt();
            // Stay in CallStatus.connecting; ringback sound will play once callee receives signal and sends ringing ACK
            _startStatusPolling();
          } else {
            _handleUnavailable(message: 'Contact is unavailable or offline');
          }
        }).catchError((_) {
          if (mounted) {
            _handleUnavailable(message: 'Contact is unavailable or offline');
          }
        });
      }
    }
  }

  void _startConnectingTimeout() {
    _connectingTimeoutTimer?.cancel();
    _connectingTimeoutTimer = Timer(Duration(seconds: 45), () {
      if (!mounted) return;
      if (_status == CallStatus.connecting) {
        _handleUnavailable(message: 'Contact is unavailable or offline');
      }
    });
  }

  void _handleUnavailable({String message = 'Contact is unavailable or offline'}) {
    if (!mounted) return;
    if (_status == CallStatus.unavailable || _status == CallStatus.ended) return;

    SoundService.instance.stopRinging();
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();

    if (_activeCallId != null) {
      try {
        ApiClient.instance.dio.post('/calls/$_activeCallId/end', data: {'duration': 0});
      } catch (_) {}
    }

    setState(() {
      _status = CallStatus.unavailable;
      _statusMessage = message;
    });

    Future.delayed(Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.microphone,
        if (widget.isVideo) Permission.camera,
      ].request();
    } catch (e) {
      debugPrint('[Permissions] Error requesting permissions: $e');
    }
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _activeCallId == null) return;
      if (_status != CallStatus.connecting && _status != CallStatus.ringing && _status != CallStatus.incoming && _status != CallStatus.connected) {
        timer.cancel();
        return;
      }

      try {
        final res = await ApiClient.instance.dio.get('/calls/$_activeCallId');
        final data = ApiClient.instance.unwrap(res);
        if (data is! Map<String, dynamic>) return;
        final call = data['call'] is Map<String, dynamic> ? data['call'] as Map<String, dynamic> : data;
        final status = call['status']?.toString();

        if (status == 'ringing' && _status == CallStatus.connecting) {
          _connectingTimeoutTimer?.cancel();
          if (mounted) {
            setState(() => _status = CallStatus.ringing);
            SoundService.instance.startOutgoingRingback();
          }
        } else if (status == 'accepted' && _status != CallStatus.connected) {
          _connectingTimeoutTimer?.cancel();
          await SoundService.instance.stopRinging();
          final token = widget.isIncoming ? null : (data['livekit_token'] ?? call['livekit_token'])?.toString();
          final host = (data['livekit_host'] ?? call['livekit_host'])?.toString();
          final startedAtStr = (data['started_at'] ?? call['started_at'])?.toString();
          if (startedAtStr != null && startedAtStr.isNotEmpty) {
            _startedAt = DateTime.tryParse(startedAtStr);
          }
          if (ref.read(callsProvider).activeCall != null) {
            ref.read(callsProvider.notifier).handleCallAccepted({
              'id': _activeCallId,
              if (token != null) 'livekit_token': token,
              'livekit_host': host,
              'started_at': startedAtStr,
            });
          }
          if (mounted) {
            setState(() {
              _status = CallStatus.connected;
            });
            _startDurationTimer();
            _connectLiveKit();
          }
        } else if (status == 'declined' && _status != CallStatus.declined) {
          timer.cancel();
          SoundService.instance.stopRinging();
          if (mounted) {
            setState(() => _status = CallStatus.declined);
            Future.delayed(Duration(milliseconds: 1200), () {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
        } else if (status == 'ended' && _status != CallStatus.ended) {
          timer.cancel();
          _onRemoteParticipantLeft();
        }
      } catch (_) {}
    });
  }

  Future<void> _initLocalCameraPreview() async {
    try {
      final track = await LocalVideoTrack.createCameraTrack();
      if (mounted) {
        setState(() {
          _localVideoTrack = track;
        });
      }
    } catch (e) {
      debugPrint('[Camera] Error creating local camera track: $e');
    }
  }

  /// Connect to LiveKit Room using active session credentials
  Future<void> _connectLiveKit() async {
    if (_isConnectingRoom) return;
    if (_room != null && _room!.connectionState == ConnectionState.connected) return;
    _isConnectingRoom = true;

    try {
      final active = ref.read(callsProvider).activeCall;
      String? token = active?.token;
      String? host = active?.host;

      // If token not present yet, fetch from backend
      if ((token == null || token.isEmpty) && _activeCallId != null) {
        debugPrint('[LiveKit] No token in state, fetching from /calls/$_activeCallId/token');
        final res = await ref.read(callsProvider.notifier).fetchCallToken(_activeCallId!);
        if (res != null) {
          token = (res['livekit_token'] ?? res['token'])?.toString();
          host = (res['livekit_host'] ?? res['host'])?.toString();
        }
      }

      if (token == null || token.isEmpty) {
        debugPrint('[LiveKit] ❌ No token available for call $_activeCallId — LiveKit not configured on server?');
        _isConnectingRoom = false;
        if (mounted) {
          _handleUnavailable(message: 'Could not connect call');
        }
        return;
      }

      // Ensure microphone permissions are explicitly requested
      final micPerm = await Permission.microphone.request();
      if (!micPerm.isGranted) {
        debugPrint('[LiveKit] ⚠️ Microphone permission not granted: $micPerm');
      }

      // Ensure ringing sound player is stopped to avoid audio focus competition
      await SoundService.instance.stopRinging();
      // Give the OS audio session time to fully release before LiveKit's WebRTC
      // engine takes over — prevents audio routing conflicts (especially on iOS).
      await Future.delayed(Duration(milliseconds: 250));

      host ??= 'wss://live-staging.murihspace.com';
      var wsHost = host.trim();
      if (wsHost.startsWith('https://')) {
        wsHost = 'wss://${wsHost.substring(8)}';
      } else if (wsHost.startsWith('http://')) {
        wsHost = 'ws://${wsHost.substring(7)}';
      }
      wsHost = wsHost.replaceAll(RegExp(r'/+$'), '');

      debugPrint('[LiveKit] Connecting to $wsHost for room ${active?.roomName}');

      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            dtx: false,
            encoding: AudioEncoding.presetSpeech,
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );
      _room = room;
      final listener = room.createListener();
      _listener = listener;

      listener
        ..on<AudioPlaybackStatusChanged>((event) async {
          debugPrint('[LiveKit] 🔊 AudioPlaybackStatusChanged: isPlaying=${event.isPlaying}');
          if (!event.isPlaying) {
            try {
              await _room?.startAudio();
            } catch (_) {}
          }
        })
        ..on<ParticipantConnectedEvent>((event) {
          debugPrint('[LiveKit] 👤 ParticipantConnected: ${event.participant.identity}');
          if (mounted) setState(() {});
        })
        ..on<TrackSubscribedEvent>((event) async {
          if (mounted && event.track is VideoTrack) {
            setState(() {
              _remoteVideoTrack = event.track as VideoTrack;
            });
          } else if (event.track is AudioTrack) {
            debugPrint('[LiveKit] 🎙️ Subscribed to remote audio track: ${event.track.sid}');
            try {
              await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
              debugPrint('[LiveKit] ✅ Configured audio output route (speaker: $_isSpeakerOn)');
            } catch (e) {
              debugPrint('[LiveKit] ⚠️ Error configuring remote audio track route: $e');
            }
          }
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((event) async {
          if (mounted && event.track is VideoTrack) {
            setState(() {
              if (_remoteVideoTrack == event.track) _remoteVideoTrack = null;
            });
          } else if (event.track is AudioTrack) {
            debugPrint('[LiveKit] Unsubscribed from remote audio track: ${event.track.sid}');
          }
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          debugPrint('[LiveKit] ⚠️ ParticipantDisconnected: ${event.participant.identity}');
          if (mounted) {
            setState(() {});
            // Apply 8s grace period before ending call in case of quick network reconnection
            Future.delayed(Duration(milliseconds: 8000), () {
              if (mounted && (_room?.remoteParticipants.isEmpty ?? true)) {
                _onRemoteParticipantLeft();
              }
            });
          }
        })
        ..on<RoomDisconnectedEvent>((event) {
          debugPrint('[LiveKit] ⚠️ RoomDisconnectedEvent reason: ${event.reason}');
          if (mounted && _status == CallStatus.connected) {
            _onRemoteParticipantLeft();
          }
        });

      await room.connect(wsHost, token);
      debugPrint('[LiveKit] ✅ Connected to room');

      try {
        await room.startAudio();
      } catch (e) {
        debugPrint('[LiveKit] ⚠️ Error calling startAudio: $e');
      }

      // Configure audio route for any existing remote audio tracks
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.audioTrackPublications) {
          if (pub.subscribed && pub.track != null) {
            debugPrint('[LiveKit] 🎙️ Existing remote audio track found: ${pub.track!.sid}');
            try {
              await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
            } catch (e) {
              debugPrint('[LiveKit] ⚠️ Error routing existing audio track: $e');
            }
          }
        }
      }

      // Configure speakerphone vs earpiece output
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(_isSpeakerOn, force: _isSpeakerOn);
      } catch (e) {
        debugPrint('[Audio] Error configuring audio output: $e');
      }

      // Publish local mic
      debugPrint('[LiveKit] Enabling local microphone...');
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (_isMuted) {
        await room.localParticipant?.setMicrophoneEnabled(false);
      }
      debugPrint('[LiveKit] ✅ Local microphone enabled (muted: $_isMuted)');

      // Publish local camera if video call
      if (widget.isVideo) {
        if (_localVideoTrack is LocalVideoTrack) {
          await room.localParticipant?.publishVideoTrack(_localVideoTrack as LocalVideoTrack);
        } else {
          await room.localParticipant?.setCameraEnabled(!_isCameraOff);
          final pubs = room.localParticipant?.videoTrackPublications;
          if (mounted && pubs != null && pubs.isNotEmpty) {
            setState(() {
              _localVideoTrack = pubs.first.track as VideoTrack?;
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _status = CallStatus.connected;
          _isConnectingRoom = false;
        });
        SoundService.instance.stopRinging();
        _ringingTimeoutTimer?.cancel();
        _startDurationTimer();
      }
    } catch (e) {
      debugPrint('[LiveKit] ❌ Error connecting to room: $e');
      _isConnectingRoom = false;
    }
  }

  void _onRemoteParticipantLeft() {
    if (_room != null && _room!.remoteParticipants.isNotEmpty) {
      if (mounted) setState(() {});
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
    if (mounted) {
      setState(() => _status = CallStatus.ended);
      Future.delayed(Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  void _showAddParticipantSheet() {
    if (_activeCallId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddParticipantSheet(
        callId: _activeCallId!,
        onInvited: (userName) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invited $userName to call'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF34C759),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _flipCamera() async {
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
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[LiveKit] Error flipping camera: $e');
        }
      }
    }
  }

  void _startDurationTimer() {
    _callTimer?.cancel();
    _updateCallSeconds();
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _status == CallStatus.connected) {
        _updateCallSeconds();
      }
    });
  }

  void _updateCallSeconds() {
    if (!mounted) return;
    if (_startedAt != null) {
      final diff = DateTime.now().toUtc().difference(_startedAt!.toUtc()).inSeconds;
      setState(() => _callSeconds = diff > 0 ? diff : 0);
    } else {
      setState(() => _callSeconds++);
    }
  }

  void _startRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(Duration(seconds: 45), () {
      if (!mounted) return;
      if (_status == CallStatus.ringing || _status == CallStatus.connecting || _status == CallStatus.incoming) {
        _handleUnavailable(message: 'No answer');
      }
    });
  }

  @override
  void dispose() {
    _connectingTimeoutTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _statusPollTimer?.cancel();
    SoundService.instance.stopRinging();
    _callTimer?.cancel();
    _pulseController.dispose();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    if (_localVideoTrack is LocalVideoTrack) {
      try {
        (_localVideoTrack as LocalVideoTrack).stop();
      } catch (_) {}
    }
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get _statusLabel {
    if (_status == CallStatus.unavailable && _statusMessage != null && _statusMessage!.isNotEmpty) {
      return _statusMessage!;
    }
    switch (_status) {
      case CallStatus.connecting:
        return 'Connecting…';
      case CallStatus.ringing:
        return 'Ringing…';
      case CallStatus.incoming:
        return widget.isVideo ? 'Incoming Video Call…' : 'Incoming Voice Call…';
      case CallStatus.connected:
        return widget.isVideo ? 'Video Call · ${_formatDuration(_callSeconds)}' : _formatDuration(_callSeconds);
      case CallStatus.declined:
        return 'Call Declined';
      case CallStatus.unavailable:
        return _statusMessage ?? 'Contact is unavailable or offline';
      case CallStatus.ended:
        return 'Call Ended';
    }
  }

  Future<void> _acceptIncomingCall() async {
    HapticFeedback.heavyImpact();
    await SoundService.instance.stopRinging();
    if (_activeCallId != null && _activeCallId! > 0) {
      final data = await ref.read(callsProvider.notifier).acceptCall(_activeCallId!);
      if (data != null) {
        final call = data['call'] is Map ? data['call'] as Map : data;
        final startedAtStr = (call['started_at'] ?? data['started_at'])?.toString();
        if (startedAtStr != null && startedAtStr.isNotEmpty) {
          _startedAt = DateTime.tryParse(startedAtStr);
        }
      }
    }
    if (mounted) {
      setState(() {
        _status = CallStatus.connected;
      });
      _startDurationTimer();
      _connectLiveKit();
    }
  }

  void _declineIncomingCall() {
    HapticFeedback.mediumImpact();
    SoundService.instance.stopRinging();
    if (_activeCallId != null && _activeCallId! > 0) {
      ref.read(callsProvider.notifier).declineCall(_activeCallId!);
    }
    if (mounted) {
      setState(() => _status = CallStatus.declined);
      Future.delayed(Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    SoundService.instance.stopRinging();
    _callTimer?.cancel();
    _statusPollTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;

    if (mounted) {
      setState(() => _status = CallStatus.ended);
    }

    if (_activeCallId != null && _activeCallId! > 0) {
      ref.read(callsProvider.notifier).endCall(_activeCallId!, durationSeconds: _callSeconds);
    } else {
      ref.read(callsProvider.notifier).logNewCall(
            contactName: widget.contactName,
            phoneNumber: widget.phoneNumber ?? '+234 812 000 1122',
            direction: widget.isIncoming ? CallDirection.incoming : CallDirection.outgoing,
            durationSeconds: _callSeconds,
            isVideo: widget.isVideo,
            avatarUrl: widget.avatarUrl ?? '',
          );
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Color(0xFF0F141C) : Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white54 : Color(0xFF64748B);
    final textMutedSoft = isDark ? Colors.white24 : Color(0xFF94A3B8);
    final iconBgColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;



    // Listen for real-time call acceptance or decline from backend events
    ref.listen<CallsState>(callsProvider, (prev, next) {
      if (!mounted) return;
      final active = next.activeCall;
      if (active == null) {
        if (_status == CallStatus.connected || _status == CallStatus.ringing || _status == CallStatus.incoming || _status == CallStatus.connecting) {
          _connectingTimeoutTimer?.cancel();
          _onRemoteParticipantLeft();
        }
      } else if (active.status == 'ringing' && _status == CallStatus.connecting) {
        _connectingTimeoutTimer?.cancel();
        if (mounted) {
          setState(() => _status = CallStatus.ringing);
          SoundService.instance.startOutgoingRingback();
        }
      } else if (active.status == 'connected' && _status != CallStatus.connected) {
        _connectingTimeoutTimer?.cancel();
        // NOTE: Do NOT call _connectLiveKit() here — _startStatusPolling() already
        // triggers it when it detects the accepted/connected status. Calling it
        // from both places publishes duplicate microphone tracks causing silence.
        SoundService.instance.stopRinging();
        if (active.startedAt != null) {
          _startedAt = active.startedAt;
        }
        _startDurationTimer();
        if (mounted) {
          setState(() => _status = CallStatus.connected);
          _connectLiveKit();
        }
      } else if (active.status == 'declined' && _status != CallStatus.declined) {
        _connectingTimeoutTimer?.cancel();
        SoundService.instance.stopRinging();
        if (mounted) {
          setState(() => _status = CallStatus.declined);
          final nav = Navigator.of(context);
          Future.delayed(Duration(milliseconds: 1200), () {
            if (mounted) nav.maybePop();
          });
        }
      }
    });

    final remoteParticipants = _room?.remoteParticipants.values.toList() ?? [];
    final isMultiParty = _status == CallStatus.connected && remoteParticipants.length > 1;
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final hasRemoteVideo = widget.isVideo && _status == CallStatus.connected && _remoteVideoTrack != null && !isMultiParty;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Canvas: Remote Video stream OR Local Camera Preview while connecting/ringing OR Dark Gradient
          if (hasRemoteVideo)
            SizedBox.expand(
              child: VideoTrackRenderer(
                _remoteVideoTrack!,
                fit: _remoteVideoTrack!.source == TrackSource.screenShareVideo
                    ? VideoViewFit.contain
                    : VideoViewFit.cover,
              ),
            )
          else if (widget.isVideo && _localVideoTrack != null && !_isCameraOff && !isMultiParty)
            SizedBox.expand(
              child: VideoTrackRenderer(
                _localVideoTrack!,
                fit: VideoViewFit.cover,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF182234), Color(0xFF0B101B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Multi-Party Video & Audio Grid
          if (isMultiParty)
            Positioned.fill(
              top: MediaQuery.of(context).padding.top + 70,
              bottom: MediaQuery.of(context).padding.bottom + 110,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: remoteParticipants.length,
                  itemBuilder: (context, index) {
                    final p = remoteParticipants[index];
                    TrackPublication? videoPub;
                    for (final pub in p.videoTrackPublications) {
                      if (pub.subscribed && pub.track != null && !pub.muted) {
                        videoPub = pub;
                        break;
                      }
                    }
                    bool isMuted = true;
                    for (final pub in p.audioTrackPublications) {
                      if (pub.subscribed && pub.track != null && !pub.muted) {
                        isMuted = false;
                        break;
                      }
                    }
                    final name = p.name.isNotEmpty ? p.name : (p.identity.isNotEmpty ? p.identity : 'User');

                    return Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (videoPub?.track != null)
                            VideoTrackRenderer(
                              videoPub!.track as VideoTrack,
                              fit: videoPub!.track!.source == TrackSource.screenShareVideo ? VideoViewFit.contain : VideoViewFit.cover,
                            )
                          else
                            Center(
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(0xFF007AFF),
                                child: Text(
                                  name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Icon(
                                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                    size: 13,
                                    color: isMuted ? Color(0xFFFF3B30) : Color(0xFF34C759),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Dark overlay gradient for contrast
          if (hasRemoteVideo || (widget.isVideo && _localVideoTrack != null && !_isCameraOff && !isMultiParty))
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Profile Avatar & Info
          // In audio calls or while ringing, centered in middle
          // In video calls when connected, moves to compact top corner
          if (!hasRemoteVideo && !isMultiParty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: (_status == CallStatus.ringing || _status == CallStatus.incoming) ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_status == CallStatus.ringing || _status == CallStatus.incoming)
                              ? Color(0xFF34C759)
                              : (_status == CallStatus.connected
                                  ? Color(0xFF007AFF)
                                  : ((_status == CallStatus.unavailable || _status == CallStatus.declined)
                                      ? Color(0xFFFF3B30)
                                      : Colors.white24)),
                          width: 3,
                        ),
                        boxShadow: (_status == CallStatus.ringing || _status == CallStatus.incoming)
                            ? [
                                BoxShadow(
                                  color: Color(0x6634C759),
                                  blurRadius: 28,
                                  spreadRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
                        backgroundColor: Color(0xFF007AFF),
                        child: !hasAvatar
                            ? Icon(Icons.person, color: textColor, size: 48)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    widget.contactName,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_status == CallStatus.unavailable || _status == CallStatus.declined)
                            ? Color(0xFFFF3B30).withValues(alpha: 0.4)
                            : Colors.white10,
                      ),
                    ),
                    child: Text(
                      widget.isVideo
                          ? (_status == CallStatus.connected
                              ? 'Video Call · ${_formatDuration(_callSeconds)}'
                              : (_status == CallStatus.unavailable
                                  ? _statusLabel
                                  : 'Video Call · $_statusLabel'))
                          : _statusLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _status == CallStatus.connected
                            ? Color(0xFF34C759)
                            : ((_status == CallStatus.ringing || _status == CallStatus.incoming)
                                ? Color(0xFFFFD60A)
                                : ((_status == CallStatus.unavailable || _status == CallStatus.declined)
                                    ? Color(0xFFFF453A)
                                    : Colors.white70)),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: _status == CallStatus.connected ? Color(0xFF34C759) : Colors.white54,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'End-to-End Encrypted',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _status == CallStatus.connected ? Color(0xFF34C759) : Colors.white54,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Inset PIP Self Video Preview (video call connected with remote video active)
          if (hasRemoteVideo && _localVideoTrack != null && !_isCameraOff)
            Positioned(
              top: MediaQuery.of(context).padding.top + 58,
              right: 16,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textMutedSoft, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: VideoTrackRenderer(
                    _localVideoTrack!,
                    fit: VideoViewFit.cover,
                  ),
                ),
              ),
            ),

          // Top App Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _status == CallStatus.incoming ? _declineIncomingCall : _endCall,
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: _status == CallStatus.connected
                            ? Color(0xFF34C759)
                            : ((_status == CallStatus.ringing || _status == CallStatus.incoming)
                                ? Color(0xFFFFD60A)
                                : ((_status == CallStatus.unavailable || _status == CallStatus.declined)
                                    ? Color(0xFFFF453A)
                                    : Colors.white70)),
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _status == CallStatus.unavailable
                            ? 'Unavailable'
                            : (isMultiParty
                                ? '${remoteParticipants.length + 1} Participants · ${_formatDuration(_callSeconds)}'
                                : _statusLabel),
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.isVideo)
                  IconButton(
                    onPressed: _flipCamera,
                    icon: Icon(Icons.flip_camera_ios_rounded, color: textColor),
                    tooltip: 'Flip Camera',
                  )
                else
                  SizedBox(width: 48),
              ],
            ),
          ),

          // Bottom Call Control Bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 20,
            right: 20,
            child: _status == CallStatus.incoming
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Decline Call
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _declineIncomingCall,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x66FF3B30),
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Decline',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        // Accept Call
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _acceptIncomingCall,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x6634C759),
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.call_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Accept',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E293B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute Mic Toggle
                        _CallActionButton(
                          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          isActive: _isMuted,
                          activeColor: Color(0xFFFF3B30),
                          label: _isMuted ? 'Muted' : 'Mute',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final next = !_isMuted;
                            await _room?.localParticipant?.setMicrophoneEnabled(!next);
                            if (mounted) setState(() => _isMuted = next);
                          },
                        ),

                        // Camera Toggle (Available for all calls now)
                        _CallActionButton(
                          icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          isActive: _isCameraOff,
                          activeColor: Color(0xFFFF3B30),
                          label: _isCameraOff ? 'Camera Off' : 'Camera',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final next = !_isCameraOff;
                            await _room?.localParticipant?.setCameraEnabled(!next);
                            if (mounted) setState(() => _isCameraOff = next);
                          },
                        ),

                        // Speakerphone Toggle
                        _CallActionButton(
                          icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          isActive: _isSpeakerOn,
                          activeColor: Color(0xFF007AFF),
                          label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final next = !_isSpeakerOn;
                            try {
                              await AudioManager.instance.setSpeakerOutputPreferred(next, force: next);
                            } catch (_) {}
                            if (mounted) setState(() => _isSpeakerOn = next);
                          },
                        ),

                        // Add Participant Button (Only when connected)
                        if (_status == CallStatus.connected)
                          _CallActionButton(
                            icon: Icons.person_add_rounded,
                            isActive: false,
                            activeColor: Color(0xFF007AFF),
                            label: 'Add',
                            onTap: _showAddParticipantSheet,
                          ),

                        // End Call Button
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66FF3B30),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final String label;
  final VoidCallback onTap;

  _CallActionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Color(0xFF0F141C) : Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white54 : Color(0xFF64748B);
    final textMutedSoft = isDark ? Colors.white24 : Color(0xFF94A3B8);
    final iconBgColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? activeColor : iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 22),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AddParticipantSheet extends ConsumerStatefulWidget {
  final int callId;
  final void Function(String userName)? onInvited;

  _AddParticipantSheet({
    required this.callId,
    this.onInvited,
  });

  @override
  ConsumerState<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends ConsumerState<_AddParticipantSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  final Set<int> _invitingIds = {};
  final Set<int> _invitedIds = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchUsers('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final q = query.trim();
      final res = q.isEmpty
          ? await ApiClient.instance.dio.get('/friends')
          : await ApiClient.instance.dio.get('/friends/search', queryParameters: {'q': q});

      final unwrapped = ApiClient.instance.unwrap(res);
      final list = unwrapped is List
          ? unwrapped
          : (unwrapped is Map && unwrapped['data'] is List ? unwrapped['data'] as List : []);

      final normalized = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final u = item['friend'] is Map
              ? Map<String, dynamic>.from(item['friend'] as Map)
              : Map<String, dynamic>.from(item);
          if (u.containsKey('id')) {
            normalized.add(u);
          }
        }
      }

      if (mounted) {
        setState(() {
          _users = normalized;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AddParticipantSheet] Error fetching contacts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      _fetchUsers(val);
    });
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = (user['id'] as num?)?.toInt();
    if (userId == null) return;

    setState(() => _invitingIds.add(userId));
    final success = await ref.read(callsProvider.notifier).inviteToCall(widget.callId, userId);
    if (!mounted) return;

    setState(() {
      _invitingIds.remove(userId);
      if (success) {
        _invitedIds.add(userId);
      }
    });

    if (success) {
      widget.onInvited?.call((user['name'] ?? 'User').toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to invite user to call'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Color(0xFF0F141C) : Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white54 : Color(0xFF64748B);
    final textMutedSoft = isDark ? Colors.white24 : Color(0xFF94A3B8);
    final iconBgColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;


    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Color(0xFF131B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator handle
          SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: textMutedSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 12),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: Color(0xFF007AFF), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Add Person to Call',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search friends by name or username...',
                  hintStyle: TextStyle(color: textMutedSoft, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: textMutedSoft, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textMutedSoft, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchUsers('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Contacts List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No matching contacts found',
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _users.length,
                        separatorBuilder: (_, _) => Divider(color: borderColor, height: 1),
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          final id = (u['id'] as num?)?.toInt() ?? 0;
                          final name = (u['name'] ?? 'User').toString();
                          final username = (u['username'] ?? '').toString();
                          final avatarUrl = (u['avatar_url'] ?? u['avatar'])?.toString();
                          final isInviting = _invitingIds.contains(id);
                          final isInvited = _invitedIds.contains(id);

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFF1E293B),
                                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: (avatarUrl == null || avatarUrl.isEmpty)
                                      ? Text(
                                          name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        )
                                      : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (username.isNotEmpty)
                                        Text(
                                          '@$username',
                                          style: TextStyle(color: textMutedSoft, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: (isInviting || isInvited) ? null : () => _inviteUser(u),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isInvited
                                        ? Color(0xFF34C759).withValues(alpha: 0.2)
                                        : Color(0xFF007AFF),
                                    foregroundColor: isInvited ? Color(0xFF34C759) : Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: isInviting
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          isInvited ? 'Invited' : 'Invite',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
