import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/send_gift_dialog.dart';

/// Live Streaming Stage with Real-Time Gifting, Live Chat, & Viewer Stats.
class LiveStreamScreen extends ConsumerStatefulWidget {
  final String streamTitle;
  final String hostName;

  const LiveStreamScreen({
    super.key,
    this.streamTitle = '🔥 Live Tech & Creator Media Launch',
    this.hostName = 'Vincent (Creator)',
  });

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  int _viewerCount = 1240;
  int _totalGiftsCoins = 14500;
  final List<String> _chatMessages = [
    'Alice: Amazing broadcast! 🔥',
    'Bob: Welcome everyone to the stream 🚀',
    'System: 🌹 Daniel sent a Magic Rose gift!',
    'Charlie: Loving the new features on MurihSpace!',
  ];
  final _chatCtrl = TextEditingController();

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _chatMessages.add('You: $text');
        _chatCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Live Stream Video Feed Canvas
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
                    backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.2),
                    child: const Icon(Icons.live_tv_rounded, color: Color(0xFFFF9500), size: 42),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.streamTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hosted by ${widget.hostName}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Top Header Overlay Bar
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('🪙 $_totalGiftsCoins Coins', style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Bottom Live Chat & Gifting Overlay Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Chat Messages Stream
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _chatMessages.length,
                      itemBuilder: (ctx, idx) {
                        final msg = _chatMessages[_chatMessages.length - 1 - idx];
                        final isGift = msg.contains('sent a');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isGift ? const Color(0xFFFF9500).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isGift ? const Color(0xFFFF9500) : Colors.white,
                              fontSize: 12,
                              fontWeight: isGift ? FontWeight.w900 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Chat Input & Gifting Toolbar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Say something live…',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.15),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _sendChat(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF007AFF)),
                        onPressed: _sendChat,
                      ),
                      const SizedBox(width: 4),
                      // Floating Gift Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9500),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => SendGiftDialog.show(
                          context,
                          recipientName: widget.hostName,
                          onGiftSent: (gift) {
                            setState(() {
                              _totalGiftsCoins += gift.coinCost;
                              _chatMessages.add('🎁 You sent ${gift.icon} ${gift.name}!');
                            });
                          },
                        ),
                        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                        label: const Text('Gift', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ],
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
