import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/router.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/calls_provider.dart';
import '../screens/call_screen.dart';
import '../core/api_client.dart';
import '../services/call_session_manager.dart';
import '../services/sound_service.dart';

/// Heads-up incoming-call banner shown while the user is inside the app.
///
/// When the app is backgrounded or terminated the OS-level CallKit UI takes
/// over instead (see [PushService]); this banner is the in-app counterpart for
/// the foreground case. It is theme-aware: light surfaces and dark ink text in
/// light mode, deep slate surfaces and light text in dark mode.
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
  bool _isAccepting = false;

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

    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
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
      if (CallSessionManager.instance.isActive) return;
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
        final current = ref.read(callsProvider).activeCall;
        if (current != null && current.status == 'incoming') {
          ref.read(callsProvider.notifier).handleCallEnded({});
        }
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
                    ? _buildIncomingCallBanner(context, activeCall)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIncomingCallBanner(BuildContext context, ActiveCallSession activeCall) {
    final isVideo = activeCall.callType == 'video';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-resolved tokens: the banner is a surface of the app, so it follows
    // the active theme instead of forcing a single dark treatment.
    final accent = DesignTokens.primary;
    final surfaceTop = isDark ? const Color(0xFF23314A) : const Color(0xFFFFFFFF);
    final surfaceBottom = isDark ? const Color(0xFF141C2B) : const Color(0xFFF5F8FC);
    final borderColor = isDark ? const Color(0xFF3B4B66) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtleColor = isDark ? const Color(0xFF9AA8BF) : const Color(0xFF64748B);

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
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF1E293B))
                      .withValues(alpha: isDark ? 0.55 : 0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [surfaceTop, surfaceBottom],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      _buildCallerAvatar(activeCall, isDark: isDark, accent: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeCall.callerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                        size: 12,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVideo ? 'VIDEO' : 'VOICE',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    isVideo ? 'Incoming video call' : 'Incoming voice call',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDeclineButton(activeCall),
                      const SizedBox(width: 8),
                      _buildAcceptButton(activeCall, isVideo: isVideo),
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

  /// Caller profile picture with a subtle themed radar ripple while ringing.
  Widget _buildCallerAvatar(
    ActiveCallSession activeCall, {
    required bool isDark,
    required Color accent,
  }) {
    final hasAvatar = activeCall.callerAvatar.isNotEmpty;
    return SizedBox(
      width: 52,
      height: 52,
      child: AnimatedBuilder(
        animation: _rippleController,
        builder: (context, _) {
          final p = _rippleController.value;
          final s1 = 1.0 + (p * 0.36);
          final o1 = (1 - p).clamp(0.0, 1.0) * 0.38;
          final p2 = (p + 0.5) % 1.0;
          final s2 = 1.0 + (p2 * 0.36);
          final o2 = (1 - p2).clamp(0.0, 1.0) * 0.38;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: s1,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: o1), width: 1.6),
                  ),
                ),
              ),
              Transform.scale(
                scale: s2,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: o2), width: 1.6),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.34 : 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasAvatar
                      ? CachedNetworkImage(
                          imageUrl: activeCall.callerAvatar,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _avatarFallback(accent),
                          errorWidget: (_, _, _) => _avatarFallback(accent),
                        )
                      : _avatarFallback(accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatarFallback(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.14),
      child: Icon(Icons.person_rounded, color: accent, size: 24),
    );
  }

  Widget _buildDeclineButton(ActiveCallSession activeCall) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          _stopRingingFeedback();
          ref.read(callsProvider.notifier).declineCall(activeCall.callId);
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF3B30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.38),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _buildAcceptButton(ActiveCallSession activeCall, {required bool isVideo}) {
    return ScaleTransition(
      scale: _pulseScale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAccepting
              ? null
              : () async {
                  setState(() => _isAccepting = true);
                  HapticFeedback.heavyImpact();
                  try {
                    final accepted = await ref
                        .read(callsProvider.notifier)
                        .acceptCall(activeCall.callId);
                    if (!mounted || accepted == null) {
                      // Accept failed on the backend — don't push a screen that
                      // claims to be connected. Ringing feedback is still running
                      // (it is only stopped after a successful accept).
                      if (mounted && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('Could not accept the call. Try again.')),
                          );
                      }
                      return;
                    }
                    _stopRingingFeedback();
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
                  } finally {
                    if (mounted) setState(() => _isAccepting = false);
                  }
                },
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF34C759),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34C759).withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
