import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/call_session_manager.dart';

/// Floating Call Overlay that renders a draggable Picture-in-Picture (PiP) mini-window
/// when the user minimizes an active call, allowing continued app navigation without dropping the call.
class FloatingCallOverlay extends StatefulWidget {
  final Widget child;

  const FloatingCallOverlay({super.key, required this.child});

  @override
  State<FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<FloatingCallOverlay> {
  Offset? _pos;

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: CallSessionManager.instance,
          builder: (context, _) {
            final call = CallSessionManager.instance;
            if (!call.isActive || !call.isMinimized) {
              return const SizedBox.shrink();
            }

            final mediaQuery = MediaQuery.of(context);
            final screenSize = mediaQuery.size;

            final isVideo = call.isVideo;
            final pipWidth = isVideo ? 128.0 : 210.0;
            final pipHeight = isVideo ? 186.0 : 76.0;

            // Default position top-right
            _pos ??= Offset(screenSize.width - pipWidth - 16, mediaQuery.padding.top + 50);

            // Clamp within screen bounds
            final minX = 8.0;
            final maxX = screenSize.width - pipWidth - 8.0;
            final minY = mediaQuery.padding.top + 8.0;
            final maxY = screenSize.height - mediaQuery.padding.bottom - pipHeight - 12.0;

            final clampedX = _pos!.dx.clamp(minX, maxX);
            final clampedY = _pos!.dy.clamp(minY, maxY);

            return Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pos = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
                  });
                },
                onTap: () {
                  call.restoreCall(context);
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: pipWidth,
                    height: pipHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        if (call.isConnected)
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isVideo
                        ? _buildVideoMiniCard(context, call)
                        : _buildAudioMiniCard(context, call),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoMiniCard(BuildContext context, CallSessionManager call) {
    final activeVideoTrack = call.remoteVideoTrack ?? (!call.isCameraOff ? call.localVideoTrack : null);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Preview Feed
        if (activeVideoTrack != null)
          VideoTrackRenderer(
            activeVideoTrack,
            fit: VideoViewFit.cover,
          )
        else
          Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF007AFF),
                backgroundImage: call.avatarUrl != null && call.avatarUrl!.isNotEmpty
                    ? NetworkImage(call.avatarUrl!)
                    : null,
                child: call.avatarUrl == null || call.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
            ),
          ),

        // Gradient Vignette for Contrast
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
        ),

        // Top duration badge and expand icon
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(call.callSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ],
          ),
        ),

        // Bottom Controls: Mute toggle and End Call
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute Mini Toggle
              GestureDetector(
                onTap: () {
                  call.toggleMute();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: call.isMuted
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF334155).withValues(alpha: 0.85),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

              // End Call Mini Button
              GestureDetector(
                onTap: () {
                  call.endCall();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF453A), Color(0xFFD70015)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMiniCard(BuildContext context, CallSessionManager call) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF007AFF),
            backgroundImage: call.avatarUrl != null && call.avatarUrl!.isNotEmpty
                ? NetworkImage(call.avatarUrl!)
                : null,
            child: call.avatarUrl == null || call.avatarUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 10),

          // Name & Duration
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.contactName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(call.callSeconds),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mini Mute
          GestureDetector(
            onTap: () => call.toggleMute(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: call.isMuted
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFF334155).withValues(alpha: 0.85),
              ),
              child: Icon(
                call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mini Hangup
          GestureDetector(
            onTap: () => call.endCall(),
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF3B30),
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

