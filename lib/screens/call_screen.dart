import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../providers/calls_provider.dart';
import '../services/sound_service.dart';

enum CallStatus {
  connecting,
  ringing,
  connected,
  declined,
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

  const CallScreen({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.avatarUrl,
    this.isVideo = false,
    this.recipientId,
    this.callId,
    this.isIncoming = false,
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
  int? _activeCallId;

  int _callSeconds = 0;
  Timer? _callTimer;

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
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isIncoming) {
      _status = CallStatus.connected;
      _callSeconds = 0;
      _startDurationTimer();
      _connectLiveKit();
    } else {
      _status = CallStatus.connecting;

      if (widget.isVideo) {
        _initLocalCameraPreview();
      }

      // Initiate call on backend
      if (widget.recipientId != null && widget.recipientId! > 0) {
        ref.read(callsProvider.notifier).initiateCall(
          recipientId: widget.recipientId!,
          type: widget.isVideo ? 'video' : 'audio',
          contactName: widget.contactName,
          avatarUrl: widget.avatarUrl,
        ).then((res) {
          if (res != null && mounted) {
            final call = res['call'] is Map ? res['call'] : res;
            _activeCallId = (call['id'] as num?)?.toInt();
            setState(() => _status = CallStatus.ringing);
            SoundService.instance.startOutgoingRingback();
          }
        });
      }
    }
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
    if (_isConnectingRoom || _room != null) return;
    _isConnectingRoom = true;

    try {
      final active = ref.read(callsProvider).activeCall;
      String? token = active?.token;
      String? host = active?.host;

      // If token not present yet, fetch from backend
      if ((token == null || host == null) && _activeCallId != null) {
        final res = await ref.read(callsProvider.notifier).fetchCallToken(_activeCallId!);
        if (res != null) {
          token = (res['livekit_token'] ?? res['token'])?.toString();
          host = (res['livekit_host'] ?? res['host'])?.toString();
        }
      }

      if (token == null || token.isEmpty) {
        debugPrint('[LiveKit] No token available for call $_activeCallId');
        _isConnectingRoom = false;
        return;
      }

      host ??= 'wss://live-staging.murihspace.com';
      var wsHost = host.trim();
      if (wsHost.startsWith('https://')) {
        wsHost = 'wss://${wsHost.substring(8)}';
      } else if (wsHost.startsWith('http://')) {
        wsHost = 'ws://${wsHost.substring(7)}';
      }
      wsHost = wsHost.replaceAll(RegExp(r'/+$'), '');

      final room = Room();
      _room = room;
      final listener = room.createListener();
      _listener = listener;

      listener
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is VideoTrack) {
            setState(() {
              _remoteVideoTrack = event.track as VideoTrack;
            });
          }
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (event.track is VideoTrack) {
            setState(() {
              if (_remoteVideoTrack == event.track) _remoteVideoTrack = null;
            });
          }
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) {
            _onRemoteParticipantLeft();
          }
        });

      await room.connect(wsHost, token);

      // Publish local mic
      await room.localParticipant?.setMicrophoneEnabled(!_isMuted);

      // Publish local camera if video call
      if (widget.isVideo) {
        if (_localVideoTrack is LocalVideoTrack) {
          await room.localParticipant?.publishVideoTrack(_localVideoTrack as LocalVideoTrack);
        } else {
          await room.localParticipant?.setCameraEnabled(!_isCameraOff);
          final pubs = room.localParticipant?.videoTrackPublications;
          if (pubs != null && pubs.isNotEmpty) {
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
        _startDurationTimer();
      }
    } catch (e) {
      debugPrint('[LiveKit] Error connecting to room: $e');
      _isConnectingRoom = false;
    }
  }

  void _onRemoteParticipantLeft() {
    SoundService.instance.stopRinging();
    if (mounted) {
      setState(() => _status = CallStatus.ended);
    }
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
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
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _status == CallStatus.connected) {
        setState(() => _callSeconds++);
      }
    });
  }

  @override
  void dispose() {
    SoundService.instance.stopRinging();
    _callTimer?.cancel();
    _pulseController.dispose();
    _listener?.dispose();
    _room?.dispose();
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
    switch (_status) {
      case CallStatus.connecting:
        return 'Connecting…';
      case CallStatus.ringing:
        return 'Ringing…';
      case CallStatus.connected:
        return widget.isVideo ? 'Video Call · ${_formatDuration(_callSeconds)}' : _formatDuration(_callSeconds);
      case CallStatus.declined:
        return 'Call Declined';
      case CallStatus.ended:
        return 'Call Ended';
    }
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    SoundService.instance.stopRinging();
    _room?.disconnect();
    _room?.dispose();
    _room = null;

    setState(() => _status = CallStatus.ended);

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
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for real-time call acceptance or decline from backend events
    ref.listen<CallsState>(callsProvider, (prev, next) {
      final active = next.activeCall;
      if (active == null) {
        if (_status == CallStatus.connected || _status == CallStatus.ringing) {
          _onRemoteParticipantLeft();
        }
      } else if (active.status == 'connected' && _status != CallStatus.connected) {
        SoundService.instance.stopRinging();
        _callSeconds = 0;
        _startDurationTimer();
        setState(() => _status = CallStatus.connected);
        _connectLiveKit();
      } else if (active.status == 'declined' && _status != CallStatus.declined) {
        SoundService.instance.stopRinging();
        setState(() => _status = CallStatus.declined);
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) nav.maybePop();
        });
      }
    });

    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final hasRemoteVideo = widget.isVideo && _status == CallStatus.connected && _remoteVideoTrack != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Canvas: Remote Video stream OR Local Camera Preview while connecting/ringing OR Dark Gradient
          if (hasRemoteVideo)
            SizedBox.expand(
              child: VideoTrackRenderer(
                _remoteVideoTrack!,
                fit: VideoViewFit.cover,
              ),
            )
          else if (widget.isVideo && _localVideoTrack != null && !_isCameraOff)
            SizedBox.expand(
              child: VideoTrackRenderer(
                _localVideoTrack!,
                fit: VideoViewFit.cover,
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF182234), Color(0xFF0B101B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Dark overlay gradient for contrast
          if (hasRemoteVideo || (widget.isVideo && _localVideoTrack != null && !_isCameraOff))
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
          if (!hasRemoteVideo)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _status == CallStatus.ringing ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _status == CallStatus.ringing
                              ? const Color(0xFF34C759)
                              : (_status == CallStatus.connected
                                  ? const Color(0xFF007AFF)
                                  : Colors.white24),
                          width: 3,
                        ),
                        boxShadow: _status == CallStatus.ringing
                            ? [
                                const BoxShadow(
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
                        backgroundColor: const Color(0xFF007AFF),
                        child: !hasAvatar
                            ? const Icon(Icons.person, color: Colors.white, size: 48)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.contactName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      widget.isVideo
                          ? (_status == CallStatus.connected
                              ? 'Video Call · ${_formatDuration(_callSeconds)}'
                              : 'Video Call · $_statusLabel')
                          : _statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _status == CallStatus.connected
                            ? const Color(0xFF34C759)
                            : (_status == CallStatus.ringing ? const Color(0xFFFFD60A) : Colors.white70),
                      ),
                    ),
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
                  border: Border.all(color: Colors.white38, width: 1.5),
                  boxShadow: const [
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
                  onPressed: _endCall,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: _status == CallStatus.connected
                            ? const Color(0xFF34C759)
                            : (_status == CallStatus.ringing ? const Color(0xFFFFD60A) : Colors.white70),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.isVideo)
                  IconButton(
                    onPressed: _flipCamera,
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                    tooltip: 'Flip Camera',
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),

          // Bottom Call Control Bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
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
                    activeColor: const Color(0xFFFF3B30),
                    label: _isMuted ? 'Muted' : 'Mute',
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final next = !_isMuted;
                      await _room?.localParticipant?.setMicrophoneEnabled(!next);
                      setState(() => _isMuted = next);
                    },
                  ),

                  // Camera Toggle (If Video Call)
                  if (widget.isVideo)
                    _CallActionButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isActive: _isCameraOff,
                      activeColor: const Color(0xFFFF3B30),
                      label: _isCameraOff ? 'Camera Off' : 'Camera',
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final next = !_isCameraOff;
                        await _room?.localParticipant?.setCameraEnabled(!next);
                        setState(() => _isCameraOff = next);
                      },
                    ),

                  // Speakerphone Toggle
                  _CallActionButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    isActive: _isSpeakerOn,
                    activeColor: const Color(0xFF007AFF),
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),

                  // End Call Button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
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
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
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

  const _CallActionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
