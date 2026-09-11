import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calls_provider.dart';
import '../screens/call_screen.dart';
import '../services/sound_service.dart';

class IncomingCallOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallOverlay({super.key, required this.child});

  @override
  ConsumerState<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _vibrationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startRingingFeedback() {
    _vibrationTimer?.cancel();
    HapticFeedback.heavyImpact();
    SoundService.instance.startIncomingRingtone();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final active = ref.read(callsProvider).activeCall;
      if (active == null || active.status != 'incoming') {
        timer.cancel();
        return;
      }
      HapticFeedback.vibrate();
    });
  }

  void _stopRingingFeedback() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    SoundService.instance.stopRinging();
  }

  @override
  void dispose() {
    _stopRingingFeedback();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCall = ref.watch(callsProvider).activeCall;
    final isIncoming = activeCall != null && activeCall.status == 'incoming';

    if (isIncoming && _vibrationTimer == null) {
      _startRingingFeedback();
    } else if (!isIncoming && _vibrationTimer != null) {
      _stopRingingFeedback();
    }

    return Stack(
      children: [
        widget.child,
        if (isIncoming && activeCall != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34C759).withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF34C759).withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseScale,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF007AFF),
                        backgroundImage: activeCall.callerAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(activeCall.callerAvatar)
                            : null,
                        child: activeCall.callerAvatar.isEmpty
                            ? Text(
                                activeCall.callerName.isNotEmpty
                                    ? activeCall.callerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeCall.callerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                activeCall.callType == 'video'
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                size: 14,
                                color: const Color(0xFF34C759),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activeCall.callType == 'video'
                                    ? 'Incoming Video Call…'
                                    : 'Incoming Voice Call…',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF34C759),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Decline Call Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _stopRingingFeedback();
                        ref.read(callsProvider.notifier).declineCall(activeCall.callId);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Accept Call Button
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        _stopRingingFeedback();
                        await ref.read(callsProvider.notifier).acceptCall(activeCall.callId);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              contactName: activeCall.callerName,
                              avatarUrl: activeCall.callerAvatar,
                              isVideo: activeCall.callType == 'video',
                              callId: activeCall.callId,
                              isIncoming: true,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
