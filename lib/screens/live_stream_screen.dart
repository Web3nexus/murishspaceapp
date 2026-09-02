import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/send_gift_dialog.dart';

/// Full Interactive Live Streaming Stage with Tap-for-Likes, Live Commerce,
/// Real-Time Gifting & Top Supporters Leaderboard, Live Chat, and Background Audio.
class LiveStreamScreen extends ConsumerStatefulWidget {
  final String streamTitle;
  final String hostName;
  final String? communityName;
  final bool cameraEnabled;
  final bool micEnabled;
  final String streamMode;
  final Map<String, dynamic>? backgroundSound;
  final Map<String, dynamic>? pinnedProduct;

  const LiveStreamScreen({
    super.key,
    this.streamTitle = '🔥 Live Tech & Creator Media Launch',
    this.hostName = 'Vincent (Creator)',
    this.communityName,
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
  int _viewerCount = 1420;
  int _likesCount = 890;
  int _totalGiftsCoins = 14500;

  late bool _cameraOn;
  late bool _micOn;
  bool _isPlayingMusic = true;
  Map<String, dynamic>? _activeProduct;

  final List<Map<String, dynamic>> _chatMessages = [
    {'name': 'Alice', 'role': 'Moderator', 'msg': 'Welcome to the broadcast everyone! 🔥', 'color': Color(0xFF007AFF)},
    {'name': 'Daniel', 'role': 'VIP', 'msg': 'Let’s go! Super excited for this session 🚀', 'color': Color(0xFFFF9500)},
    {'name': 'Grace', 'role': 'Member', 'msg': 'Audio and video are crystal clear!', 'color': Color(0xFF34C759)},
  ];
  final _chatCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Floating Hearts Animation State
  final List<_FloatingHeart> _hearts = [];
  final Random _random = Random();

  // Top Gifters Leaderboard
  final List<Map<String, dynamic>> _topGifters = [
    {'name': 'Daniel Craig', 'username': 'daniel_c', 'coins': 5200, 'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200'},
    {'name': 'Alice Freeman', 'username': 'alice_f', 'coins': 3400, 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200'},
    {'name': 'Michael Jordan', 'username': 'mj_23', 'coins': 2100, 'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200'},
  ];

  @override
  void initState() {
    super.initState();
    _cameraOn = widget.cameraEnabled;
    _micOn = widget.micEnabled;
    _activeProduct = widget.pinnedProduct;
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({
        'name': 'You',
        'role': 'Host',
        'msg': text,
        'color': const Color(0xFFFF3B30),
      });
      _chatCtrl.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _addHeart(TapUpDetails details) {
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
  }

  void _openGiftingModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        recipientId: 1,
        recipientName: widget.hostName,
        onGiftSent: (gift, amount) {
          setState(() {
            _totalGiftsCoins += amount;
            _chatMessages.add({
              'name': 'System',
              'role': 'Gift',
              'msg': '🎁 You sent ${gift.name} (+$amount Coins)!',
              'color': const Color(0xFFFF9500),
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF9500),
              content: Text('Sent ${gift.name} (+$amount Coins) to ${widget.hostName}!'),
            ),
          );
        },
      ),
    );
  }

  void _showLeaderboard() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Color(0xFFFF9500), size: 24),
                  SizedBox(width: 8),
                  Text('Top Stream Supporters', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                itemCount: _topGifters.length,
                separatorBuilder: (_, _) => const Divider(color: Colors.grey, height: 1),
                itemBuilder: (context, idx) {
                  final g = _topGifters[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(g['avatar'] as String),
                    ),
                    title: Text(g['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('@${g['username']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('🪙 ${g['coins']} Coins', style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _addHeart,
        child: Stack(
          children: [
            // Background Live Stream Feed Canvas
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
                  ],
                ),
              ),
            ),

            // Floating Animated Hearts Layer
            ..._hearts.map((heart) => _FloatingHeartWidget(
                  key: ValueKey(heart.id),
                  heart: heart,
                  onComplete: () {
                    if (mounted) setState(() => _hearts.remove(heart));
                  },
                )),

            // Top Header Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Text('$_likesCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showLeaderboard,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF9500), size: 14),
                              const SizedBox(width: 4),
                              Text('🪙 $_totalGiftsCoins', style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),

                  // Background Music / Sound Bar (If Active)
                  if (widget.backgroundSound != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: Color(0xFFFF9500), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '🎵 ${widget.backgroundSound!['title']} (${widget.backgroundSound!['artist'] ?? 'Murih'})',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _isPlayingMusic = !_isPlayingMusic),
                            child: Icon(
                              _isPlayingMusic ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: const Color(0xFFFF9500),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Chat & Live Commerce Pinned Card & Interaction Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pinned Product Live Commerce Card
                    if (_activeProduct != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF34C759).withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _activeProduct!['image_url'] as String,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34C759),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('PINNED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(_activeProduct!['price'] as String, style: const TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeProduct!['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF34C759),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Opening ${_activeProduct!['title']} checkout!')),
                                );
                              },
                              child: const Text('Buy Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),

                    // Chat Stream List
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _chatMessages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _chatMessages[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (msg['color'] as Color).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    msg['role'] as String,
                                    style: TextStyle(color: msg['color'] as Color, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${msg['name']}: ',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Expanded(
                                  child: Text(
                                    msg['msg'] as String,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Input & Action Controls
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Say something in live chat…',
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF007AFF), size: 18),
                                onPressed: _sendChat,
                              ),
                            ),
                            onSubmitted: (_) => _sendChat(),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Toggle Camera Button
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          radius: 20,
                          child: IconButton(
                            icon: Icon(_cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _cameraOn = !_cameraOn),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Toggle Mic Button
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          radius: 20,
                          child: IconButton(
                            icon: Icon(_micOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _micOn = !_micOn),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Gift Button
                        GestureDetector(
                          onTap: _openGiftingModal,
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFFF9500),
                            radius: 20,
                            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  const _FloatingHeartWidget({super.key, required this.heart, required this.onComplete});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late double _endX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
    _scale = Tween<double>(begin: 0.6, end: 1.6).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _endX = widget.heart.startX + (Random().nextDouble() * 60 - 30);

    _controller.forward().then((_) => widget.onComplete());
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
        final double progress = _controller.value;
        final double currentY = widget.heart.startY - (progress * 180);
        final double currentX = widget.heart.startX + sin(progress * pi * 2) * 20;

        return Positioned(
          left: currentX,
          top: currentY,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Icon(Icons.favorite_rounded, color: widget.heart.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
