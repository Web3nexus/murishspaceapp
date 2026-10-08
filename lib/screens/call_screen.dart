import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../components/chat_pattern_background.dart';
import '../core/api_client.dart';
import '../providers/calls_provider.dart';
import '../providers/messages_provider.dart';
import '../services/call_session_manager.dart';
import 'conversation_screen.dart';

/// Real-Time Voice & Video Call Screen powered by LiveKit WebRTC SFU.
/// Features a modern WhatsApp-inspired call UX:
/// - Explicit connection state machine: Calling -> Ringing -> Connecting (with spinner) -> Connected.
/// - Top-Right controls: [+] [↻] [•••] (Add Person, Flip Camera, More Menu).
/// - Clean bottom bar: Mute | Hang Up.
/// - WhatsApp-style movable PiP preview: First tap expands, second tap swaps.
/// - Three-dot More Actions: Share Screen, Send Message, Emoji Reactions, Audio Route.
/// - Floating animated emoji reactions.
/// - Navigation preservation: call never disconnects on page change or minimize.
class CallScreen extends ConsumerStatefulWidget {
  final String contactName;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isVideo;
  final int? recipientId;
  final int? callId;
  final bool isIncoming;
  final bool isAccepted;
  final int? conversationId;

  const CallScreen({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.avatarUrl,
    this.isVideo = false,
    this.recipientId,
    this.callId,
    this.isIncoming = false,
    this.isAccepted = false,
    this.conversationId,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Local state for dragging the PiP video window within the call screen
  Offset? _pipOffset;
  bool _isPipExpanded = false;
  bool _popScheduled = false;

  /// Dismisses the screen for an ended or failed call.
  ///
  /// The route is registered with `canPop: false` so that a system back
  /// minimises instead of hanging up, and `maybePop()` honours that flag —
  /// which also blocks this screen's own dismissals. `pop()` bypasses
  /// PopScope, and the guard keeps the post-frame callback from scheduling
  /// it again on every status notification.
  void _closeScreen() {
    if (_popScheduled || !mounted) return;
    _popScheduled = true;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize or attach to global call session manager
    CallSessionManager.instance.initOrAttachCall(
      contactName: widget.contactName,
      avatarUrl: widget.avatarUrl,
      phoneNumber: widget.phoneNumber,
      isVideo: widget.isVideo,
      callId: widget.callId,
      isIncoming: widget.isIncoming,
      isAccepted: widget.isAccepted,
      recipientId: widget.recipientId,
      conversationId: widget.conversationId,
      onInitiateFailed: () {
        _closeScreen();
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // CRITICAL: Do NOT disconnect LiveKit room in dispose!
    // Room lifecycle is managed globally by CallSessionManager so that navigating
    // to Messages, Communities, Feed, or minimizing preserves the active call.
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showAddParticipantSheet() {
    final callId = CallSessionManager.instance.activeCallId ?? widget.callId;
    if (callId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddParticipantSheet(
        callId: callId,
        onInvited: (userName) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invited $userName to call'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF34C759),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showMoreActionsSheet(BuildContext context) {
    final call = CallSessionManager.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreActionsSheet(
        call: call,
        onAddPerson: () {
          Navigator.of(ctx).pop();
          _showAddParticipantSheet();
        },
        onSendMessage: () {
          Navigator.of(ctx).pop();
          _showInCallMessageSheet(context);
        },
      ),
    );
  }

  void _showInCallMessageSheet(BuildContext context) {
    final call = CallSessionManager.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _InCallMessageSheet(
        call: call,
        onOpenFullChat: () {
          Navigator.of(ctx).pop();
          // Minimize call into floating PiP and open full ConversationScreen
          call.minimizeCall(context);
          final convId = call.conversationId ?? widget.conversationId;
          if (convId != null && convId > 0) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConversationScreen(conversationId: convId),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Instead of terminating the call, convert into floating PiP window
          CallSessionManager.instance.minimizeCall(context);
        }
      },
      child: ListenableBuilder(
        listenable: CallSessionManager.instance,
        builder: (context, _) {
          final call = CallSessionManager.instance;

          // Auto-pop if call has genuinely ended
          if (call.status == CallStatus.ended) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _closeScreen();
            });
          }

          final isConnected = call.isConnected;
          final isWaiting = !isConnected;
          final isConnecting = call.status == CallStatus.connecting;
          final isReconnecting = call.status == CallStatus.reconnecting;
          final isIncomingWaiting = call.status == CallStatus.ringing && call.isIncoming && !call.isAccepted;

          return Scaffold(
            backgroundColor: const Color(0xFF0B101B),
            body: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Video / Chat Wallpaper Canvas
                _buildBackgroundCanvas(call),

                // 2. Incoming / Outgoing / Connecting State Presentation
                if (isWaiting)
                  _buildWaitingPresentation(call, isIncomingWaiting, isConnecting)
                else
                  // 3. Active Multi-Party Grid (if more than 1 remote participant)
                  if (_isMultiParty(call))
                    _buildMultiPartyGrid(call)
                  else
                    // 4. Picture-in-Picture Secondary Video Window (Active 1-on-1 call)
                    if (call.isVideo) _buildPipWindow(context, call),

                // 5. Reconnecting Banner if network temporarily drops
                if (isReconnecting)
                  _buildReconnectingBanner(),

                // 6. Top Safe Area Controls (Minimize, Duration, [+] [↻] [•••])
                _buildTopControls(context, call, isConnected),

                // 7. Floating Emoji Reaction Bubbles
                _buildReactionOverlay(call),

                // 8. Bottom Call Controls Bar
                _buildBottomControls(context, call, isWaiting, isIncomingWaiting, isConnecting),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isMultiParty(CallSessionManager call) {
    final remoteParticipants = call.room?.remoteParticipants.values.toList() ?? [];
    return call.isConnected && remoteParticipants.length > 1;
  }

  // --- 1. Background Canvas ---
  Widget _buildBackgroundCanvas(CallSessionManager call) {
    final hasRemoteVideo = call.isVideo && call.remoteVideoTrack != null;
    final hasLocalVideo = call.isVideo && call.localVideoTrack != null && !call.isCameraOff;

    VideoTrack? mainVideoTrack;
    if (call.isVideo && call.isConnected) {
      if (call.isSwapped) {
        mainVideoTrack = call.localVideoTrack ?? call.remoteVideoTrack;
      } else {
        mainVideoTrack = call.remoteVideoTrack ?? call.localVideoTrack;
      }
    } else if (call.isVideo && hasLocalVideo) {
      mainVideoTrack = call.localVideoTrack;
    }

    if (mainVideoTrack != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_isPipExpanded) {
            setState(() => _isPipExpanded = false);
          } else if (call.isConnected && call.isVideo && hasRemoteVideo && hasLocalVideo) {
            call.swapVideos();
          }
        },
        child: SizedBox.expand(
          child: VideoTrackRenderer(
            mainVideoTrack,
            fit: mainVideoTrack.source == TrackSource.screenShareVideo
                ? VideoViewFit.contain
                : VideoViewFit.cover,
          ),
        ),
      );
    }

    // Default Voice / Waiting Canvas: Dark slate gradient + MurihSpace Chat Pattern
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF0B101B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        ChatPatternBackground(child: const SizedBox.expand()),
      ],
    );
  }

  // --- 2. Waiting & Connecting Presentation ---
  Widget _buildWaitingPresentation(CallSessionManager call, bool isIncoming, bool isConnecting) {
    final hasAvatar = call.avatarUrl != null && call.avatarUrl!.isNotEmpty;

    String statusText;
    if (isConnecting) {
      statusText = 'Connecting…';
    } else if (isIncoming) {
      statusText = call.isVideo ? 'Incoming Video Call…' : 'Incoming Voice Call…';
    } else if (call.status == CallStatus.ringing) {
      statusText = 'Ringing…';
    } else if (call.status == CallStatus.connectionFailed) {
      statusText = 'Connection failed';
    } else {
      statusText = 'Calling…';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Radar pulse avatar
          ScaleTransition(
            scale: isConnecting ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isIncoming
                      ? const Color(0xFF34C759)
                      : const Color(0xFF007AFF).withValues(alpha: 0.6),
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isIncoming ? const Color(0xFF34C759) : const Color(0xFF007AFF))
                        .withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: const Color(0xFF007AFF),
                    backgroundImage: hasAvatar ? CachedNetworkImageProvider(call.avatarUrl!) : null,
                    child: !hasAvatar
                        ? const Icon(Icons.person, color: Colors.white, size: 54)
                        : null,
                  ),
                  if (isConnecting)
                    const SizedBox(
                      width: 136,
                      height: 136,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF34C759)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Caller Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              call.contactName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status Badge Pill (Never show Disconnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isConnecting)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759)),
                    ),
                  )
                else if (!isIncoming)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD60A),
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isIncoming
                        ? const Color(0xFF34D399)
                        : (isConnecting ? const Color(0xFF34C759) : Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Reconnecting Banner ---
  Widget _buildReconnectingBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFB45309).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Reconnecting call…',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. Picture-in-Picture Draggable Window (WhatsApp-style: Tap 1 expands, Tap 2 swaps) ---
  Widget _buildPipWindow(BuildContext context, CallSessionManager call) {
    final hasRemoteVideo = call.remoteVideoTrack != null;
    final hasLocalVideo = call.localVideoTrack != null && !call.isCameraOff;

    if (!hasRemoteVideo && !hasLocalVideo) return const SizedBox.shrink();

    final pipTrack = call.isSwapped ? call.remoteVideoTrack : call.localVideoTrack;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Normal vs Expanded Dimensions (WhatsApp-style first tap preview expansion)
    final pipW = _isPipExpanded ? 168.0 : 114.0;
    final pipH = _isPipExpanded ? 240.0 : 162.0;

    _pipOffset ??= Offset(
      screenSize.width - 114.0 - 16,
      mediaQuery.padding.top + 70,
    );

    final minX = 8.0;
    final maxX = screenSize.width - pipW - 8.0;
    final minY = mediaQuery.padding.top + 60.0;
    final maxY = screenSize.height - mediaQuery.padding.bottom - pipH - 90.0;

    final clampedX = _pipOffset!.dx.clamp(minX, maxX);
    final clampedY = _pipOffset!.dy.clamp(minY, maxY);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipOffset = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
          });
        },
        onTap: () {
          HapticFeedback.lightImpact();
          if (!_isPipExpanded) {
            // First tap: expand the preview temporarily
            setState(() => _isPipExpanded = true);
          } else {
            // Second tap: swap small video with main video!
            call.swapVideos();
            setState(() => _isPipExpanded = false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: pipW,
          height: pipH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPipExpanded
                  ? const Color(0xFF007AFF)
                  : Colors.white.withValues(alpha: 0.3),
              width: _isPipExpanded ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            color: const Color(0xFF1E293B),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pipTrack != null)
                VideoTrackRenderer(
                  pipTrack,
                  fit: VideoViewFit.cover,
                )
              else
                Center(
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF007AFF),
                    child: Text(
                      call.contactName.isNotEmpty
                          ? call.contactName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Swap Hint Indicator / Tap Hint
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPipExpanded ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      if (_isPipExpanded) ...[
                        const SizedBox(width: 3),
                        const Text(
                          'Swap',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. Multi-Party Grid ---
  Widget _buildMultiPartyGrid(CallSessionManager call) {
    final remoteParticipants = call.room?.remoteParticipants.values.toList() ?? [];

    return Positioned.fill(
      top: MediaQuery.of(context).padding.top + 70,
      bottom: MediaQuery.of(context).padding.bottom + 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            final name = p.name.isNotEmpty ? p.name : (p.identity.isNotEmpty ? p.identity : 'User');

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (videoPub?.track != null)
                    VideoTrackRenderer(
                      videoPub!.track as VideoTrack,
                      fit: VideoViewFit.cover,
                    )
                  else
                    Center(
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF007AFF),
                        child: Text(
                          name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 6. Top Safe Area Controls: [+] [↻] [•••] ---
  Widget _buildTopControls(BuildContext context, CallSessionManager call, bool isConnected) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Minimize button & Live duration timer
          Row(
            children: [
              _buildTopIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Minimize call',
                onTap: () {
                  call.minimizeCall(context);
                },
              ),
              if (isConnected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(call.callSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Right: Exact [+] [↻] [•••] actions requested
          if (isConnected)
            Row(
              children: [
                // 1. Add Participant [+]
                _buildTopIconButton(
                  icon: Icons.person_add_rounded,
                  tooltip: 'Add Person',
                  onTap: _showAddParticipantSheet,
                ),
                const SizedBox(width: 8),

                // 2. Switch Camera [↻] (Front <-> Back)
                if (call.isVideo) ...[
                  _buildTopIconButton(
                    icon: Icons.flip_camera_ios_rounded,
                    tooltip: 'Switch Camera',
                    onTap: () => call.flipCamera(),
                  ),
                  const SizedBox(width: 8),
                ],

                // 3. More Actions [•••]
                _buildTopIconButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'More actions',
                  onTap: () => _showMoreActionsSheet(context),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // --- 7. Floating Reaction Overlay ---
  Widget _buildReactionOverlay(CallSessionManager call) {
    if (call.activeReactions.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: call.activeReactions.map((reaction) {
            return _FloatingReactionBubble(
              key: ValueKey(reaction.id),
              emoji: reaction.emoji,
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- 8. Bottom Call Controls Bar ---
  Widget _buildBottomControls(
    BuildContext context,
    CallSessionManager call,
    bool isWaiting,
    bool isIncomingWaiting,
    bool isConnecting,
  ) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 20,
      right: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: isWaiting
            ? _buildWaitingBottomBar(call, isIncomingWaiting, isConnecting)
            : _buildActiveBottomBar(context, call),
      ),
    );
  }

  // Waiting Bottom Bar: Decline/Accept (incoming) or Hang Up (outgoing/connecting)
  Widget _buildWaitingBottomBar(CallSessionManager call, bool isIncoming, bool isConnecting) {
    if (isIncoming && !isConnecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline Button
          _buildCircleButton(
            icon: Icons.call_end_rounded,
            label: 'Decline',
            backgroundColor: const Color(0xFFFF3B30),
            size: 60,
            onTap: () => call.declineCall(),
          ),

          // Accept Button with Glowing Pulse
          ScaleTransition(
            scale: _pulseAnimation,
            child: _buildCircleButton(
              icon: call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              label: 'Accept',
              backgroundColor: const Color(0xFF34C759),
              size: 66,
              glowColor: const Color(0x7734C759),
              onTap: () => call.acceptCall(),
            ),
          ),
        ],
      );
    }

    // Outgoing or Connecting state: Prominent End Call button
    return Center(
      child: _buildCircleButton(
        icon: Icons.call_end_rounded,
        label: isConnecting ? 'Cancel' : 'End Call',
        backgroundColor: const Color(0xFFFF3B30),
        size: 64,
        glowColor: const Color(0x66FF3B30),
        onTap: () => call.endCall(),
      ),
    );
  }

  // Active Bottom Bar: Focused Primary Controls: Mute | Hang Up
  Widget _buildActiveBottomBar(BuildContext context, CallSessionManager call) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Mute Toggle Button
                _buildBarActionButton(
                  icon: call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: call.isMuted ? 'Unmute' : 'Mute',
                  isActive: call.isMuted,
                  activeColor: const Color(0xFFFF3B30),
                  onTap: () => call.toggleMute(),
                ),

                const SizedBox(width: 32),

                // 2. Hang Up Button (Prominent Destructive Action)
                GestureDetector(
                  onTap: () => call.endCall(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF453A), Color(0xFFD70015)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.55),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'End',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? activeColor
                  : const Color(0xFF334155).withValues(alpha: 0.85),
              border: Border.all(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required double size,
    Color? glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: [
                if (glowColor != null)
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.46),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Reaction Bubble that drifts upward with sinusoidal horizontal wobble and fade
class _FloatingReactionBubble extends StatefulWidget {
  final String emoji;

  const _FloatingReactionBubble({super.key, required this.emoji});

  @override
  State<_FloatingReactionBubble> createState() => _FloatingReactionBubbleState();
}

class _FloatingReactionBubbleState extends State<_FloatingReactionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _startX;

  @override
  void initState() {
    super.initState();
    _startX = 0.65 + (math.Random().nextDouble() * 0.22); // Spawn near bottom right
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final size = MediaQuery.of(context).size;

        // Upward translation from 75% height to 20% height
        final y = size.height * (0.75 - (progress * 0.55));
        // Slight horizontal sinusoidal wave drift
        final x = (size.width * _startX) + (math.sin(progress * 4 * math.pi) * 16);

        // Scale pop-in then gentle drift
        final scale = progress < 0.2
            ? (progress / 0.2) * 1.3
            : (1.3 - ((progress - 0.2) * 0.35));

        // Fade out during last 30%
        final opacity = progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.2, 1.4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// More Actions Popover Sheet containing Emoji Reactions, Camera toggle, Speaker toggle,
/// Screen Share, and Messages action
class _MoreActionsSheet extends StatelessWidget {
  final CallSessionManager call;
  final VoidCallback onAddPerson;
  final VoidCallback onSendMessage;

  const _MoreActionsSheet({
    required this.call,
    required this.onAddPerson,
    required this.onSendMessage,
  });

  static const _emojis = ['❤️', '👍', '😂', '😮', '🔥', '👏', '🎉'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          const Text(
            'Call Actions & Reactions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Emoji Quick Reaction Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _emojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    call.sendReaction(emoji);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Action Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Camera Toggle (for video call)
              if (call.isVideo)
                _buildActionTile(
                  icon: call.isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: call.isCameraOff ? 'Camera Off' : 'Camera On',
                  isActive: !call.isCameraOff,
                  onTap: () {
                    call.toggleCamera();
                    Navigator.of(context).pop();
                  },
                ),

              // 2. Speaker Output Toggle
              _buildActionTile(
                icon: call.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label: call.isSpeakerOn ? 'Speaker' : 'Earpiece',
                isActive: call.isSpeakerOn,
                onTap: () {
                  call.toggleSpeaker();
                  Navigator.of(context).pop();
                },
              ),

              // 3. Share Screen Toggle
              _buildActionTile(
                icon: call.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                label: call.isScreenSharing ? 'Stop Share' : 'Share Screen',
                isActive: call.isScreenSharing,
                onTap: () {
                  call.toggleScreenShare();
                  Navigator.of(context).pop();
                },
              ),

              // 4. Send Message (In-Call Chat)
              _buildActionTile(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                isActive: false,
                onTap: onSendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF1E293B),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// In-Call Message Bottom Sheet allowing quick texting while keeping the call active
class _InCallMessageSheet extends ConsumerStatefulWidget {
  final CallSessionManager call;
  final VoidCallback onOpenFullChat;

  const _InCallMessageSheet({
    required this.call,
    required this.onOpenFullChat,
  });

  @override
  ConsumerState<_InCallMessageSheet> createState() => _InCallMessageSheetState();
}

class _InCallMessageSheetState extends ConsumerState<_InCallMessageSheet> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final convId = widget.call.conversationId;
    if (convId == null || convId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active conversation linked to this call.'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(conversationMessagesProvider(convId).notifier).sendMessage(content: text);
      if (mounted) {
        _messageController.clear();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            backgroundColor: Color(0xFF34C759),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Message ${widget.call.contactName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: widget.onOpenFullChat,
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF007AFF)),
                label: const Text(
                  'Open Chat',
                  style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message Input Field
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add Participant Sheet allowing inviting friends during call
class _AddParticipantSheet extends ConsumerStatefulWidget {
  final int callId;
  final ValueChanged<String>? onInvited;

  const _AddParticipantSheet({required this.callId, this.onInvited});

  @override
  ConsumerState<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends ConsumerState<_AddParticipantSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  final Set<int> _invitingIds = {};
  Timer? _searchDebounce;
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers(String query) async {
    // A slow response for an earlier keystroke must not overwrite the
    // results of a later one.
    final seq = ++_searchSeq;
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {
        'q': query,
        'limit': 20,
      });
      final unwrapped = ApiClient.instance.unwrap(res);
      final list = unwrapped is List ? unwrapped : (unwrapped is Map && unwrapped['users'] is List ? unwrapped['users'] as List : []);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _users = list.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && seq == _searchSeq) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = (user['id'] as num?)?.toInt();
    if (userId == null) return;

    setState(() => _invitingIds.add(userId));
    HapticFeedback.lightImpact();

    final success = await ref.read(callsProvider.notifier).inviteToCall(widget.callId, userId);

    if (mounted) {
      setState(() => _invitingIds.remove(userId));
      if (success) {
        widget.onInvited?.call((user['name'] ?? 'User').toString());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to invite user to call'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF131B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: Color(0xFF007AFF), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Add Person to Call',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (query) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) _fetchUsers(query);
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search friends by name or username…',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
                : _users.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final id = (user['id'] as num?)?.toInt() ?? 0;
                          final name = (user['name'] ?? user['username'] ?? 'User').toString();
                          final username = (user['username'] ?? '').toString();
                          final avatar = (user['avatar_url'] ?? user['avatar'])?.toString();
                          final isInviting = _invitingIds.contains(id);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF007AFF),
                              backgroundImage: avatar != null && avatar.isNotEmpty
                                  ? CachedNetworkImageProvider(avatar)
                                  : null,
                              child: avatar == null || avatar.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: username.isNotEmpty
                                ? Text('@$username', style: const TextStyle(color: Colors.white38, fontSize: 12))
                                : null,
                            trailing: ElevatedButton(
                              onPressed: isInviting ? null : () => _inviteUser(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              ),
                              child: isInviting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
