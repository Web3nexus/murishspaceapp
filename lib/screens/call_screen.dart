import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/calls_provider.dart';

/// Interactive Real-Time Voice & Video Call Screen with Mute, Camera Toggles,
/// Speakerphone, Camera Switch, and Live Duration Timer.
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

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  late bool _isCameraOff;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  bool _isConnected = false;

  int _callSeconds = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _isCameraOff = !widget.isVideo;
    _isSpeakerOn = widget.isVideo;

    // Simulate connecting sequence
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isConnected = true);
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padStart(2, '0');
    final secs = (seconds % 60).toString().padStart(2, '0');
    return '$mins:$secs';
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      body: Stack(
        children: [
          // Background Canvas (Video feed simulation or blurred dark gradient)
          if (widget.isVideo && !_isCameraOff)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
                      backgroundColor: const Color(0xFF007AFF),
                      child: !hasAvatar
                          ? Text(
                              widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'HD Video Call Active',
                      style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.5), width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 58,
                        backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
                        backgroundColor: const Color(0xFF007AFF),
                        child: !hasAvatar
                            ? Text(
                                widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.contactName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !_isConnected ? 'Calling…' : _formatDuration(_callSeconds),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: !_isConnected ? Colors.white70 : const Color(0xFF34C759),
                      ),
                    ),
                  ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: const Color(0xFF34C759),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isConnected ? _formatDuration(_callSeconds) : 'Connecting…',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.isVideo)
                  IconButton(
                    onPressed: () {
                      setState(() => _isFrontCamera = !_isFrontCamera);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_isFrontCamera ? 'Front Camera' : 'Back Camera')),
                      );
                    },
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
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
