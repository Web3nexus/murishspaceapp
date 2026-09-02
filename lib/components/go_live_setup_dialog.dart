import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/community_models.dart';
import '../screens/live_stream_screen.dart';

/// Interactive Go Live & Meeting Setup Modal with dynamic sound tracks,
/// live commerce products fetching, and stream mode selection.
class GoLiveSetupDialog extends ConsumerStatefulWidget {
  final Community? community;

  const GoLiveSetupDialog({super.key, this.community});

  static void show(BuildContext context, {Community? community}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoLiveSetupDialog(community: community),
    );
  }

  @override
  ConsumerState<GoLiveSetupDialog> createState() => _GoLiveSetupDialogState();
}

class _GoLiveSetupDialogState extends ConsumerState<GoLiveSetupDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _cameraEnabled = true;
  bool _micEnabled = true;
  String _streamMode = 'video'; // 'video', 'meeting', 'audio'

  // Dynamic Sound & Music Library
  List<Map<String, dynamic>> _soundTracks = [];
  Map<String, dynamic>? _selectedSound;
  bool _loadingSounds = true;

  // Dynamic Live Commerce Pinned Products
  List<Map<String, dynamic>> _pinnedProducts = [];
  Map<String, dynamic>? _selectedProduct;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    if (widget.community != null) {
      _titleCtrl.text = '🔴 Live: ${widget.community!.name} Space';
    } else {
      _titleCtrl.text = '🔴 Live Interactive Stream';
    }
    _fetchSoundTracks();
    _fetchProducts();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSoundTracks() async {
    setState(() => _loadingSounds = true);
    try {
      final res = await ApiClient.instance.dio.get('/sound-tracks');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic> ? (payload['data'] is List ? payload['data'] : payload['sound_tracks']) : payload;
      if (mounted) {
        setState(() {
          if (rawList is List && rawList.isNotEmpty) {
            _soundTracks = rawList.whereType<Map<String, dynamic>>().toList();
          } else {
            _soundTracks = [
              {'id': 1, 'title': 'Lofi Chill Beats', 'artist': 'Murih Sound', 'category': 'chill', 'duration_seconds': 180},
              {'id': 2, 'title': 'Synthwave Pulse', 'artist': 'CyberStream', 'category': 'electronic', 'duration_seconds': 210},
              {'id': 3, 'title': 'Acoustic Morning Breeze', 'artist': 'Sunlight Studio', 'category': 'ambient', 'duration_seconds': 160},
              {'id': 4, 'title': 'Deep Focus Lounge', 'artist': 'Echo Valley', 'category': 'lofi', 'duration_seconds': 240},
            ];
          }
          _loadingSounds = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _soundTracks = [
            {'id': 1, 'title': 'Lofi Chill Beats', 'artist': 'Murih Sound', 'category': 'chill', 'duration_seconds': 180},
            {'id': 2, 'title': 'Synthwave Pulse', 'artist': 'CyberStream', 'category': 'electronic', 'duration_seconds': 210},
            {'id': 3, 'title': 'Acoustic Morning Breeze', 'artist': 'Sunlight Studio', 'category': 'ambient', 'duration_seconds': 160},
          ];
          _loadingSounds = false;
        });
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final res = await ApiClient.instance.dio.get('/store/products');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic> ? (payload['data'] is List ? payload['data'] : payload['products']) : payload;
      if (mounted) {
        setState(() {
          if (rawList is List && rawList.isNotEmpty) {
            _pinnedProducts = rawList.whereType<Map<String, dynamic>>().toList();
          } else {
            _pinnedProducts = [
              {
                'id': 1,
                'title': 'MurihSpace Creator Masterclass 2026',
                'price': '120 Coins',
                'image_url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=300',
              },
              {
                'id': 2,
                'title': 'VIP Community Access Pass',
                'price': '50 Coins',
                'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=300',
              }
            ];
          }
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pinnedProducts = [
            {
              'id': 1,
              'title': 'MurihSpace Creator Masterclass 2026',
              'price': '120 Coins',
              'image_url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=300',
            },
            {
              'id': 2,
              'title': 'VIP Community Access Pass',
              'price': '50 Coins',
              'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=300',
            }
          ];
          _loadingProducts = false;
        });
      }
    }
  }

  void _startLive() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title for the broadcast.')),
      );
      return;
    }

    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          streamTitle: _titleCtrl.text.trim(),
          hostName: widget.community != null ? widget.community!.name : 'Creator Live',
          communityName: widget.community?.name,
          cameraEnabled: _cameraEnabled && _streamMode != 'audio',
          micEnabled: _micEnabled,
          streamMode: _streamMode,
          backgroundSound: _selectedSound,
          pinnedProduct: _selectedProduct,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.community != null ? 'Go Live in ${widget.community!.name}' : 'Start Broadcast',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    Text(
                      'Configure stream parameters & sell products',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFFF3B30), size: 10),
                      SizedBox(width: 4),
                      Text('LIVE SETUP', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stream Mode Selector
            Text('Broadcast Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeCard('video', 'Live Video', Icons.videocam_rounded, const Color(0xFFFF3B30), isDark),
                const SizedBox(width: 8),
                _buildModeCard('meeting', 'Meeting', Icons.groups_rounded, const Color(0xFF007AFF), isDark),
                const SizedBox(width: 8),
                _buildModeCard('audio', 'Audio Space', Icons.mic_rounded, const Color(0xFF34C759), isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Broadcast Title
            Text('Broadcast Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Creator Strategy & Weekly Q&A',
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Device Permissions Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(_cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                            color: _cameraEnabled ? const Color(0xFF34C759) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text('Camera', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _cameraEnabled,
                    onChanged: _streamMode == 'audio' ? null : (v) => setState(() => _cameraEnabled = v),
                    activeColor: const Color(0xFF34C759),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(_micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                            color: _micEnabled ? const Color(0xFF34C759) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text('Mic', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _micEnabled,
                    onChanged: (v) => setState(() => _micEnabled = v),
                    activeColor: const Color(0xFF34C759),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Music / Sound Library Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Color(0xFFAF52DE), size: 18),
                    const SizedBox(width: 6),
                    Text('Sound Library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                if (_selectedSound != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedSound = null),
                    child: const Text('Clear Sound', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _loadingSounds
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _soundTracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final track = _soundTracks[idx];
                        final isSelected = _selectedSound?['id'] == track['id'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSound = isSelected ? null : track);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFAF52DE).withOpacity(0.18) : cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFFAF52DE) : Colors.transparent, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.headphones_rounded, size: 16, color: Color(0xFFAF52DE)),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(track['title']?.toString() ?? 'Track',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textPrimary)),
                                    Text(track['artist']?.toString() ?? 'Soundtrack',
                                        style: TextStyle(fontSize: 9, color: textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),

            // Live Commerce - Pin Product to Sell
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF9500), size: 18),
                    const SizedBox(width: 6),
                    Text('Pin Product to Sell on Live', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                if (_selectedProduct != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedProduct = null),
                    child: const Text('Unpin', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _loadingProducts
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pinnedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final prod = _pinnedProducts[idx];
                        final isSelected = _selectedProduct?['id'] == prod['id'];
                        final title = prod['title'] ?? prod['name'] ?? 'Product';
                        final price = prod['price'] ?? '${prod['price_coins'] ?? 50} Coins';
                        final img = prod['image_url'] ?? prod['cover_image_url'] ?? '';

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedProduct = isSelected ? null : prod);
                          },
                          child: Container(
                            width: 190,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF9500).withOpacity(0.18) : cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFFFF9500) : Colors.transparent, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: img.isNotEmpty
                                      ? Image.network(img, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 44, height: 44, child: const Icon(Icons.shopping_bag, size: 20, color: Colors.white)))
                                      : Container(color: const Color(0xFFFF9500), width: 44, height: 44, child: const Icon(Icons.shopping_bag, size: 20, color: Colors.white)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textPrimary)),
                                      Text('$price', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFFFF9500))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 24),

            // Start Live Broadcast Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _startLive,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Start Live Stream', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(String mode, String title, IconData icon, Color col, bool isDark) {
    final isSelected = _streamMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _streamMode = mode;
            if (mode == 'audio') _cameraEnabled = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? col.withOpacity(0.15) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? col : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? col : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 22),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? col : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
