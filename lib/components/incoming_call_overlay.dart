import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/router.dart';
import '../providers/auth_provider.dart';
import '../providers/calls_provider.dart';
import '../screens/call_screen.dart';
import '../core/api_client.dart';
import '../services/sound_service.dart';

class IncomingCallOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallOverlay({super.key, required this.child});

  @override
  ConsumerState<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with TickerProviderStateMixin {
  Timer? _vibrationTimer;
  Timer? _ringTimeoutTimer;
  Timer? _pollTimer;

  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  late AnimationController _rippleController;

  bool _isBannerVisible = false;

  @override
  void initState() {
    super.initState();

    // Entrance / Exit animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Breathing pulse for the Accept button & ringing indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ripple wave for the caller avatar radar effect
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Resilient Polling Heartbeat (Fallback to guarantee web/mobile call signaling arrives)
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted) return;
      final authUser = ref.read(authProvider).user;
      if (authUser == null) return;

      // Only poll when no active call session is already present
      final currentCall = ref.read(callsProvider).activeCall;
      if (currentCall != null) return;

      try {
        final res = await ApiClient.instance.dio.get('/calls/incoming/active');
        final data = ApiClient.instance.unwrap(res);
        if (data is Map<String, dynamic>) {
          final call = data['call'] is Map<String, dynamic>
              ? data['call'] as Map<String, dynamic>
              : data;
          final status = call['status']?.toString();
          if (status == 'connecting' || status == 'ringing') {
            if (mounted && ref.read(callsProvider).activeCall == null) {
              ref.read(callsProvider.notifier).handleIncomingCall(data);
            }
          }
        }
      } catch (_) {
        // Quietly handle network or auth errors
      }
    });
  }

  void _startRingingFeedback() {
    _vibrationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    HapticFeedback.heavyImpact();
    SoundService.instance.startIncomingRingtone();

    final activeCall = ref.read(callsProvider).activeCall;
    if (activeCall != null && activeCall.callId > 0) {
      ApiClient.instance.dio.post('/calls/${activeCall.callId}/ringing').ignore();
    }

    _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
      _stopRingingFeedback();
      if (mounted) {
        ref.read(callsProvider.notifier).handleCallEnded({});
      }
    });

    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) async {
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

      // Check if caller already hung up on backend
      try {
        final res = await ApiClient.instance.dio.get('/calls/${active.callId}');
        final data = ApiClient.instance.unwrap(res);
        if (data is Map<String, dynamic>) {
          final call = data['call'] is Map<String, dynamic>
              ? data['call'] as Map<String, dynamic>
              : data;
          final status = call['status']?.toString();
          if (status == 'ended' || status == 'declined' || status == 'cancelled') {
            timer.cancel();
            _stopRingingFeedback();
            ref.read(callsProvider.notifier).handleCallEnded({});
          }
        }
      } catch (_) {}
    });
  }

  void _stopRingingFeedback() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    SoundService.instance.stopRinging();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stopRingingFeedback();
    _entranceController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCall = ref.watch(callsProvider).activeCall;
    final isIncoming = activeCall != null && activeCall.status == 'incoming';

    if (isIncoming && !_isBannerVisible) {
      _isBannerVisible = true;
      _startRingingFeedback();
      _entranceController.forward();
    } else if (!isIncoming && _isBannerVisible) {
      _isBannerVisible = false;
      _stopRingingFeedback();
      _entranceController.reverse();
    }

    return Stack(
      children: [
        widget.child,
        if (isIncoming || _entranceController.isAnimating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: activeCall != null
                    ? _buildFancyCallBanner(context, activeCall)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFancyCallBanner(BuildContext context, ActiveCallSession activeCall) {
    final isVideo = activeCall.callType == 'video';

    return Dismissible(
      key: ValueKey('incoming_call_${activeCall.callId}'),
      direction: DismissDirection.up,
      onDismissed: (_) {
        _stopRingingFeedback();
        ref.read(callsProvider.notifier).declineCall(activeCall.callId);
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            _stopRingingFeedback();
            rootNavigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  contactName: activeCall.callerName,
                  avatarUrl: activeCall.callerAvatar,
                  isVideo: isVideo,
                  callId: activeCall.callId,
                  isIncoming: true,
                  isAccepted: false,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                // Glowing emerald rim accent shadow
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                // Deep dark elevation shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0F172A).withValues(alpha: 0.94),
                        const Color(0xFF1E293B).withValues(alpha: 0.96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Animated Radar Ripple Caller Avatar
                      _buildRadarAvatar(activeCall),

                      const SizedBox(width: 12),

                      // Caller Info & Animated Ringing Status
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
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                // Call Type Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVideo
                                            ? Icons.videocam_rounded
                                            : Icons.call_rounded,
                                        size: 11,
                                        color: const Color(0xFF34D399),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVideo ? 'VIDEO' : 'VOICE',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF34D399),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Pulsing Ringing Equalizer
                                _buildMiniEqualizer(),
                                const SizedBox(width: 4),
                                const Text(
                                  'Ringing…',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Decline Action Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _stopRingingFeedback();
                            ref.read(callsProvider.notifier).declineCall(activeCall.callId);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF453A), Color(0xFFD70015)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Accept Action Button with Glowing Pulse
                      ScaleTransition(
                        scale: _pulseScale,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.heavyImpact();
                              _stopRingingFeedback();
                              await ref.read(callsProvider.notifier).acceptCall(activeCall.callId);
                              if (!context.mounted) return;
                              rootNavigatorKey.currentState?.push(
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(
                                    contactName: activeCall.callerName,
                                    avatarUrl: activeCall.callerAvatar,
                                    isVideo: isVideo,
                                    callId: activeCall.callId,
                                    isIncoming: true,
                                    isAccepted: true,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(26),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.55),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Animated Avatar with radar ripple waves
  Widget _buildRadarAvatar(ActiveCallSession activeCall) {
    return SizedBox(
      width: 54,
      height: 54,
      child: AnimatedBuilder(
        animation: _rippleController,
        builder: (context, _) {
          final progress = _rippleController.value;
          final scale1 = 1.0 + (progress * 0.45);
          final opacity1 = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

          final progress2 = (progress + 0.5) % 1.0;
          final scale2 = 1.0 + (progress2 * 0.45);
          final opacity2 = (1.0 - progress2).clamp(0.0, 1.0) * 0.45;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer radar ripple 1
              Transform.scale(
                scale: scale1,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: opacity1),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              // Outer radar ripple 2
              Transform.scale(
                scale: scale2,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF34D399).withValues(alpha: opacity2),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Center Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: activeCall.callerAvatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: activeCall.callerAvatar,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF0284C7),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF0284C7),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF0284C7),
                          child: const Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Mini animated equalizer bars
  Widget _buildMiniEqualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final t = _pulseController.value;
        final h1 = 4.0 + (t * 6.0);
        final h2 = 10.0 - (t * 5.0);
        final h3 = 5.0 + (t * 5.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2),
            _buildBar(h2),
            const SizedBox(width: 2),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.2,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF34D399),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
