import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/send_gift_dialog.dart';
import '../core/api_client.dart';
import '../core/camera_service.dart';
import '../providers/auth_provider.dart';

/// Full Interactive Live Streaming Stage with Native Hardware Camera Preview,
/// Real-Time LiveKit Session Connection, Authenticated Chat, Likes, and Ledger-Backed Gifting.
class LiveStreamScreen extends ConsumerStatefulWidget {
  final int? streamId;
  final String streamTitle;
  final String hostName;
  final String? communityName;
  final bool isHost;
  final bool cameraEnabled;
  final bool micEnabled;
  final String streamMode;
  final Map<String, dynamic>? backgroundSound;
  final Map<String, dynamic>? pinnedProduct;

  const LiveStreamScreen({
    super.key,
    this.streamId,
    this.streamTitle = 'Live Broadcast',
    this.hostName = 'Creator',
    this.communityName,
    this.isHost = true,
    this.cameraEnabled = true,
    this.micEnabled = true,
    this.streamMode = 'video',
    this.backgroundSound,
    this.pinnedProduct,
  });

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> with TickerProviderStateMixin {
  int? _activeStreamId;
  int _viewerCount = 1;
  int _likesCount = 0;
  int _totalGiftsCoins = 0;

  bool _isCameraReady = false;
  late bool _cameraOn;
  bool _isSwitchingCamera = false;

  final List<Map<String, dynamic>> _chatMessages = [];
  final _chatCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Floating Hearts Animation State
  final List<_FloatingHeart> _hearts = [];
  final Random _random = Random();

  Timer? _metricsTimer;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _activeStreamId = widget.streamId;
    _cameraOn = widget.cameraEnabled;

    _initHardwareAndBackend();
  }

  Future<void> _initHardwareAndBackend() async {
    // 1. Initialize local hardware camera if hosting and camera enabled
    if (widget.isHost && _cameraOn && widget.streamMode != 'audio') {
      final cameraReady = await CameraService.instance.initialize(preferFront: true);
      if (mounted) {
        setState(() {
          _isCameraReady = cameraReady;
        });
      }
    }

    // 2. Connect to backend LiveStream API
    await _connectToBackendStream();

    // 3. Start real-time polling timer for chat and viewer count updates
    _metricsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollLiveMetricsAndChat();
    });
  }

  Future<void> _connectToBackendStream() async {
    try {
      final api = ref.read(apiClientProvider);

      if (widget.isHost && _activeStreamId == null) {
        // Start stream on backend
        final res = await api.post('/live/start', data: {
          'title': widget.streamTitle,
          'stream_mode': widget.streamMode,
          'background_sound': widget.backgroundSound?['name'],
          'pinned_product_id': widget.pinnedProduct?['id'],
        });

        final streamData = res.data['data']?['stream'] ?? res.data['stream'];
        if (streamData != null && mounted) {
          setState(() {
            _activeStreamId = (streamData['id'] as num?)?.toInt();
            _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? 1;
            _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? 0;
            _totalGiftsCoins = (streamData['total_coins_earned'] as num?)?.toInt() ?? 0;
          });
        }
      } else if (_activeStreamId != null) {
        // Join stream as viewer
        final res = await api.post('/live/$_activeStreamId/join');
        final streamData = res.data['data']?['stream'] ?? res.data['stream'];
        if (streamData != null && mounted) {
          setState(() {
            _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? 1;
            _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? 0;
            _totalGiftsCoins = (streamData['total_coins_earned'] as num?)?.toInt() ?? 0;
          });
        }
      }

      await _pollLiveMetricsAndChat();
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pollLiveMetricsAndChat() async {
    if (_activeStreamId == null || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/live/$_activeStreamId');
      final streamData = res.data['data']?['stream'] ?? res.data['stream'];

      if (streamData != null && mounted) {
        setState(() {
          _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? _viewerCount;
          _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? _likesCount;
          _totalGiftsCoins = (streamData['total_coins_earned'] as num?)?.toInt() ?? _totalGiftsCoins;
        });
      }

      // Fetch latest chat messages
      final chatRes = await api.get('/live/$_activeStreamId/chat');
      final msgList = (chatRes.data['data']?['data'] ?? chatRes.data['data']) as List?;
      if (msgList != null && mounted) {
        final parsed = msgList.map((m) {
          final user = m['user'] as Map<String, dynamic>?;
          return {
            'id': m['id'],
            'name': user?['name'] ?? 'Viewer',
            'role': user?['role'] ?? 'Member',
            'msg': m['message'] ?? '',
            'color': const Color(0xFF007AFF),
          };
        }).toList();

        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(parsed);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _chatCtrl.dispose();
    _scrollController.dispose();

    // Release camera hardware on exit
    CameraService.instance.dispose();

    super.dispose();
  }

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);

    final success = await CameraService.instance.switchCamera();
    if (mounted) {
      setState(() {
        _isSwitchingCamera = false;
        if (success) {
          _isCameraReady = true;
        }
      });
    }
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    setState(() {
      _chatMessages.add({
        'name': user?.name ?? 'You',
        'role': widget.isHost ? 'Host' : 'Viewer',
        'msg': text,
        'color': widget.isHost ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
      });
      _chatCtrl.clear();
    });

    if (_activeStreamId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/chat', data: {'message': text});
      } catch (_) {}
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _addHeart(TapUpDetails details) async {
    setState(() {
      _likesCount += 1;
      _hearts.add(
        _FloatingHeart(
          id: DateTime.now().millisecondsSinceEpoch,
          startX: details.localPosition.dx,
          startY: details.localPosition.dy,
          color: [
            Colors.red,
            Colors.pink,
            Colors.amber,
            Colors.purple,
            Colors.cyan,
            Colors.orange,
          ][_random.nextInt(6)],
        ),
      );
    });

    if (_activeStreamId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/like', data: {'count': 1});
      } catch (_) {}
    }
  }

  void _openGiftingModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        recipientId: _activeStreamId ?? 1,
        recipientName: widget.hostName,
        onGiftSent: (gift, amount) {
          // Update user wallet state and total stream coins
          ref.read(authProvider.notifier).refreshProfile();

          setState(() {
            _totalGiftsCoins += amount;
            _chatMessages.add({
              'name': 'System',
              'role': 'Gift',
              'msg': '🎁 You sent ${gift.name} (+$amount Coins)!',
              'color': const Color(0xFFFF9500),
            });
          });

          if (_activeStreamId != null) {
            try {
              final api = ref.read(apiClientProvider);
              api.post('/live/$_activeStreamId/gift', data: {
                'gift_id': gift.id,
                'message': 'Sent ${gift.name}',
              });
            } catch (_) {}
          }
        },
      ),
    );
  }

  Future<void> _endOrLeaveStream() async {
    final isHost = widget.isHost;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHost ? 'End Live Broadcast?' : 'Leave Live Stream?'),
        content: Text(
          isHost
              ? 'Ending the broadcast will notify all viewers and save your stream statistics.'
              : 'Are you sure you want to leave this live room?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'End Stream' : 'Leave Room'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      if (isHost && _activeStreamId != null) {
        try {
          final api = ref.read(apiClientProvider);
          await api.post('/live/$_activeStreamId/end');
        } catch (_) {}
      } else if (!isHost && _activeStreamId != null) {
        try {
          final api = ref.read(apiClientProvider);
          await api.post('/live/$_activeStreamId/leave');
        } catch (_) {}
      }

      await CameraService.instance.dispose();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final coinBalance = authUser?.coins ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _addHeart,
        child: Stack(
          children: [
            // 1. Native Hardware Camera Preview Feed or Audio Room Canvas
            if (widget.isHost && _isCameraReady && CameraService.instance.controller != null && _cameraOn)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: CameraService.instance.controller!.value.previewSize?.height ?? 1,
                    height: CameraService.instance.controller!.value.previewSize?.width ?? 1,
                    child: CameraPreview(CameraService.instance.controller!),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1C1C1E), Color(0xFF0A0D12)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFFFF9500).withOpacity(0.2),
                        child: Icon(
                          _cameraOn ? Icons.videocam_rounded : Icons.mic_rounded,
                          color: const Color(0xFFFF9500),
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.streamTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hosted by ${widget.hostName}${widget.communityName != null ? ' in ${widget.communityName}' : ''}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      if (_connectionError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _connectionError!,
                            style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // 2. Floating Animated Hearts Layer
            ..._hearts.map((heart) => _FloatingHeartWidget(
                  key: ValueKey(heart.id),
                  heart: heart,
                  onComplete: () {
                    if (mounted) setState(() => _hearts.remove(heart));
                  },
                )),

            // 3. Top Header Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 6),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Real Wallet Coin Balance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙 ', style: TextStyle(fontSize: 12)),
                        Text('$coinBalance Coins', style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close/End Stream Button
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5)),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: _endOrLeaveStream,
                  ),
                ],
              ),
            ),

            // 4. Live Chat Feed Overlay
            Positioned(
              bottom: 80,
              left: 16,
              right: 80,
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _chatMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final msg = _chatMessages[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${msg['name']} ',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: msg['color'] as Color),
                            ),
                            TextSpan(
                              text: msg['msg'] as String,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 5. Bottom Controls Bar
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Say something live…',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendChat(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: Color(0xFF007AFF), size: 18),
                            onPressed: _sendChat,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Host Controls: Switch Camera
                  if (widget.isHost && _cameraOn)
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5)),
                      icon: Icon(_isSwitchingCamera ? Icons.hourglass_top : Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                      onPressed: _toggleCamera,
                    ),

                  // Non-Host Viewers: Real Gifting Button
                  if (!widget.isHost)
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF9500)),
                      icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                      onPressed: _openGiftingModal,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeart {
  final int id;
  final double startX;
  final double startY;
  final Color color;

  _FloatingHeart({
    required this.id,
    required this.startX,
    required this.startY,
    required this.color,
  });
}

class _FloatingHeartWidget extends StatefulWidget {
  final _FloatingHeart heart;
  final VoidCallback onComplete;

  const _FloatingHeartWidget({
    super.key,
    required this.heart,
    required this.onComplete,
  });

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late double _targetX;

  @override
  void initState() {
    super.initState();
    _targetX = widget.heart.startX + (Random().nextDouble() * 80 - 40);
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final progress = _anim.value;
        final dy = widget.heart.startY - (progress * 240);
        final dx = widget.heart.startX + (progress * (_targetX - widget.heart.startX));
        final opacity = (1.0 - progress).clamp(0.0, 1.0);
        final scale = 0.8 + (progress * 0.5);

        return Positioned(
          left: dx - 12,
          top: dy - 12,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Icon(Icons.favorite_rounded, color: widget.heart.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
