import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../core/design_tokens.dart';
import '../services/live_session_manager.dart';

/// Floating Live Overlay that renders a draggable Picture-in-Picture (PiP) mini-window
/// when the user minimizes an active live stream, allowing continued app navigation.
class FloatingLiveOverlay extends StatefulWidget {
  final Widget child;

  const FloatingLiveOverlay({super.key, required this.child});

  @override
  State<FloatingLiveOverlay> createState() => _FloatingLiveOverlayState();
}

class _FloatingLiveOverlayState extends State<FloatingLiveOverlay> {
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: LiveSessionManager.instance,
          builder: (context, _) {
            final live = LiveSessionManager.instance;
            if (!live.isActive || !live.isMinimized) {
              return const SizedBox.shrink();
            }

            final mediaQuery = MediaQuery.of(context);
            final screenSize = mediaQuery.size;

            const pipWidth = 136.0;
            const pipHeight = 198.0;

            // Default position top-right
            _pos ??= Offset(
              screenSize.width - pipWidth - 16,
              mediaQuery.padding.top + 50,
            );

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
                    _pos = Offset(
                      clampedX + details.delta.dx,
                      clampedY + details.delta.dy,
                    );
                  });
                },
                onTap: () {
                  live.restoreLive(context);
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: pipWidth,
                    height: pipHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF10141D),
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
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video Feed or Audio Avatar Visualizer
                        if (live.videoTrack != null)
                          VideoTrackRenderer(
                            live.videoTrack!,
                            fit: VideoViewFit.cover,
                          )
                        else
                          Container(
                            color: const Color(0xFF10141D),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: DesignTokens.primary,
                                    backgroundImage: live.hostAvatarUrl != null &&
                                            live.hostAvatarUrl!.isNotEmpty
                                        ? NetworkImage(live.hostAvatarUrl!)
                                        : null,
                                    child: live.hostAvatarUrl == null ||
                                            live.hostAvatarUrl!.isEmpty
                                        ? Text(
                                            live.hostName.isNotEmpty
                                                ? live.hostName[0].toUpperCase()
                                                : 'L',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  const Icon(
                                    Icons.mic_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Top gradient overlay with badges
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2D55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    live.closeLive();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom gradient with title and host name
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  live.streamTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  live.hostName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

