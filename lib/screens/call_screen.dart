import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calls_provider.dart';

enum CallStatus {
  connecting,
  ringing,
  connected,
  ended,
}

/// Interactive Real-Time Voice & Video Call Screen with Mute, Camera Toggles,
/// Speakerphone, Camera Switch, realistic Connecting -> Ringing -> Connected flow,
/// and live Camera Preview for video calls.
class CallScreen extends ConsumerStatefulWidget {
  final String contactName;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.avatarUrl,
    this.isVideo = false,
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

  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _statusTransitionTimer;
  Timer? _ringingHapticTimer;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _cameraReady = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isCameraOff = !widget.isVideo;
    _isSpeakerOn = widget.isVideo;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isVideo) {
      _initCamera();
    }

    _startCallProgression();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        final front = _availableCameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _availableCameras.first,
        );
        _cameraController = CameraController(
          front,
          ResolutionPreset.medium,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _cameraReady = true);
        }
      }
    } catch (e) {
      debugPrint('Call camera initialization error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    _isFrontCamera = !_isFrontCamera;
    final targetDirection = _isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;
    final target = _availableCameras.firstWhere(
      (c) => c.lensDirection == targetDirection,
      orElse: () => _availableCameras.first,
    );
    try {
      await _cameraController?.dispose();
      _cameraController = CameraController(target, ResolutionPreset.medium, enableAudio: true);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error flipping camera: $e');
    }
  }

  void _startCallProgression() {
    // Step 1: Connecting (1.5s)
    _statusTransitionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _status = CallStatus.ringing);
      HapticFeedback.lightImpact();

      // Soft vibration every 2.5s while ringing
      _ringingHapticTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
        if (!mounted || _status != CallStatus.ringing) {
          timer.cancel();
          return;
        }
        HapticFeedback.selectionClick();
      });

      // Step 2: Ringing for 4.5s -> Connected
      _statusTransitionTimer = Timer(const Duration(milliseconds: 4500), () {
        if (!mounted) return;
        _ringingHapticTimer?.cancel();
        setState(() => _status = CallStatus.connected);
        HapticFeedback.mediumImpact();
        _startDurationTimer();
      });
    });
  }

  void _startDurationTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _status == CallStatus.connected) {
        setState(() => _callSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _statusTransitionTimer?.cancel();
    _ringingHapticTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
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
      case CallStatus.ended:
        return 'Call Ended';
    }
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    setState(() => _status = CallStatus.ended);
    ref.read(callsProvider.notifier).logNewCall(
          contactName: widget.contactName,
          phoneNumber: widget.phoneNumber ?? '+234 812 000 1122',
          direction: CallDirection.outgoing,
          durationSeconds: _callSeconds,
          isVideo: widget.isVideo,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final isCameraActive = widget.isVideo && !_isCameraOff && _cameraReady && _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Canvas: Real Camera Preview when active, or Dark Gradient
          if (isCameraActive)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
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
          if (isCameraActive)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Center Contact & Status Info (or overlay on video)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _status == CallStatus.ringing ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _status == CallStatus.ringing
                            ? const Color(0xFF34C759).withValues(alpha: 0.8)
                            : (_status == CallStatus.connected
                                ? const Color(0xFF007AFF).withValues(alpha: 0.6)
                                : Colors.white24),
                        width: 3,
                      ),
                      boxShadow: _status == CallStatus.ringing
                          ? [
                              BoxShadow(
                                color: const Color(0xFF34C759).withValues(alpha: 0.35),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: widget.isVideo ? 48 : 58,
                      backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
                      backgroundColor: const Color(0xFF007AFF),
                      child: !hasAvatar
                          ? Text(
                              widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: widget.isVideo ? 36 : 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.contactName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
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
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
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
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),

                  // Camera Toggle (If Video Call)
                  if (widget.isVideo)
                    _CallActionButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isActive: _isCameraOff,
                      activeColor: const Color(0xFFFF3B30),
                      label: _isCameraOff ? 'Camera Off' : 'Camera',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isCameraOff = !_isCameraOff);
                        if (!_isCameraOff && (_cameraController == null || !_cameraController!.value.isInitialized)) {
                          _initCamera();
                        }
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
              color: isActive ? activeColor : Colors.white.withOpacity(0.15),
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
