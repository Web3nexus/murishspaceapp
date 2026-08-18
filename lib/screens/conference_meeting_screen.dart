import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/send_gift_dialog.dart';

/// Multi-User Group Conference Meeting Screen with Hand Raising, Host Controls, & Gifting.
class ConferenceMeetingScreen extends ConsumerStatefulWidget {
  final String meetingTitle;
  final String meetingId;

  const ConferenceMeetingScreen({
    super.key,
    this.meetingTitle = 'Creator Strategy & Community Conference',
    this.meetingId = 'conf-9482-nxt',
  });

  @override
  ConsumerState<ConferenceMeetingScreen> createState() => _ConferenceMeetingScreenState();
}

class _ConferenceMeetingScreenState extends ConsumerState<ConferenceMeetingScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _handRaised = false;

  static final _participants = [
    {'name': 'Vincent (Host)', 'role': 'Host', 'avatar': '', 'isSpeaking': true},
    {'name': 'Alice Freeman', 'role': 'Speaker', 'avatar': '', 'isSpeaking': false},
    {'name': 'Bob Smith', 'role': 'Speaker', 'avatar': '', 'isSpeaking': false},
    {'name': 'Pulse Activewear', 'role': 'Sponsor', 'avatar': '', 'isSpeaking': false},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = const Color(0xFF10141A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.meetingTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Row(
              children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFF34C759), size: 14),
                const SizedBox(width: 4),
                Text(
                  'ID: ${widget.meetingId} · 4 Participants',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Copy Meeting Link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://murihspace.com/meet/${widget.meetingId}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meeting link copied to clipboard!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
            tooltip: 'Send Gift to Host',
            onPressed: () => SendGiftDialog.show(context, recipientName: 'Vincent (Host)'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hand Raised Banner
          if (_handRaised)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFF9500),
              child: const Row(
                children: [
                  Text('✋ You raised your hand. Host notified!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),

          // Participants 2x2 Video Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: _participants.map((p) {
                  final isSpeaking = p['isSpeaking'] as bool;
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C222B),
                      borderRadius: BorderRadius.circular(18),
                      border: isSpeaking ? Border.all(color: const Color(0xFF34C759), width: 2) : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
                                child: Text(
                                  (p['name'] as String)[0],
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(p['role'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isSpeaking)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('SPEAKING', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Bottom Control Panel Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1C222B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _controlBtn(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _isMuted ? 'Muted' : 'Mute',
                  color: _isMuted ? const Color(0xFFFF3B30) : Colors.white,
                  onTap: () => setState(() => _isMuted = !_isMuted),
                ),
                _controlBtn(
                  icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: _isCameraOff ? 'Cam Off' : 'Camera',
                  color: _isCameraOff ? const Color(0xFFFF3B30) : Colors.white,
                  onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                ),
                _controlBtn(
                  icon: Icons.front_hand_rounded,
                  label: _handRaised ? 'Hand Up' : 'Raise',
                  color: _handRaised ? const Color(0xFFFF9500) : Colors.white,
                  onTap: () => setState(() => _handRaised = !_handRaised),
                ),
                _controlBtn(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Gift',
                  color: const Color(0xFFFF9500),
                  onTap: () => SendGiftDialog.show(context, recipientName: 'Conference Host'),
                ),
                _controlBtn(
                  icon: Icons.call_end_rounded,
                  label: 'Leave',
                  color: const Color(0xFFFF3B30),
                  onTap: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
