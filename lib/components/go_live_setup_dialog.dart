import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/community_models.dart';
import '../screens/live_stream_screen.dart';

/// Interactive Go-Live & Meeting Setup Sheet before starting a broadcast.
class GoLiveSetupDialog extends ConsumerStatefulWidget {
  final Community? community;

  const GoLiveSetupDialog({super.key, this.community});

  static Future<void> show(BuildContext context, {Community? community}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GoLiveSetupDialog(community: community),
    );
  }

  @override
  ConsumerState<GoLiveSetupDialog> createState() => _GoLiveSetupDialogState();
}

class _GoLiveSetupDialogState extends ConsumerState<GoLiveSetupDialog> {
  final _titleCtrl = TextEditingController(text: '🔥 Live Interactive Stream & Launch');
  final _descCtrl = TextEditingController();

  String _streamMode = 'video'; // video, meeting, audio
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _isRecorded = true;

  List<Map<String, dynamic>> _soundTracks = [];
  Map<String, dynamic>? _selectedSound;
  bool _loadingSounds = false;

  final List<Map<String, dynamic>> _pinnedProducts = [
    {
      'id': 1,
      'title': 'Premium Creator Masterclass Pass',
      'price': '₦15,000 / \$20',
      'image_url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=300',
    },
    {
      'id': 2,
      'title': 'MurihSpace VIP Community Access Pass',
      'price': '50 Coins',
      'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=300',
    }
  ];
  Map<String, dynamic>? _selectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.community != null) {
      _titleCtrl.text = '🔴 Live: ${widget.community!.name} Space';
    }
    _fetchSoundTracks();
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
      final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
      if (mounted) {
        setState(() {
          _soundTracks = rawList is List ? rawList.whereType<Map<String, dynamic>>().toList() : [];
          _loadingSounds = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSounds = false);
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
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
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
                width: 38,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Color(0xFFFF3B30), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Go Live & Host Meeting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                      Text(widget.community != null ? 'Broadcasting in ${widget.community!.name}' : 'Start a live interactive stream', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Stream Mode Tabs
            Text('Broadcast Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeOption('video', 'Live Video', Icons.videocam_rounded, isDark),
                const SizedBox(width: 8),
                _buildModeOption('meeting', 'Meeting Room', Icons.groups_rounded, isDark),
                const SizedBox(width: 8),
                _buildModeOption('audio', 'Audio Space', Icons.mic_rounded, isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Stream Title
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Stream / Meeting Title *',
                hintText: 'e.g. Community Tech & Growth Launch',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Short Agenda / Topic',
                hintText: 'What will you be discussing?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Device & Media Toggles
            Text('Device & Stream Permissions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  if (_streamMode != 'audio')
                    SwitchListTile(
                      title: Text('Enable Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                      subtitle: Text('Stream video feed to viewers', style: TextStyle(fontSize: 12, color: textSecondary)),
                      secondary: const Icon(Icons.camera_alt_rounded, color: Color(0xFF007AFF)),
                      value: _cameraEnabled,
                      onChanged: (val) => setState(() => _cameraEnabled = val),
                    ),
                  SwitchListTile(
                    title: Text('Enable Microphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                    subtitle: Text('Allow audio broadcasting', style: TextStyle(fontSize: 12, color: textSecondary)),
                    secondary: const Icon(Icons.mic_rounded, color: Color(0xFF34C759)),
                    value: _micEnabled,
                    onChanged: (val) => setState(() => _micEnabled = val),
                  ),
                  SwitchListTile(
                    title: Text('Record Stream', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                    subtitle: Text('Save recording for replays', style: TextStyle(fontSize: 12, color: textSecondary)),
                    secondary: const Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFFF3B30)),
                    value: _isRecorded,
                    onChanged: (val) => setState(() => _isRecorded = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Background Music & Sound Library Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sound & Music Library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                if (_selectedSound != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedSound = null),
                    child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSoundPicker(isDark, textPrimary, textSecondary),
            const SizedBox(height: 14),

            // Live Commerce: Pin Product to Sell
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sell Product on Live (Live Commerce)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                if (_selectedProduct != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedProduct = null),
                    child: const Text('Unpin', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildProductPicker(isDark, textPrimary, textSecondary),
            const SizedBox(height: 22),

            // CTA Button
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sensors_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _streamMode == 'meeting' ? 'Start Meeting' : 'Start Live Broadcast',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

  Widget _buildModeOption(String mode, String label, IconData icon, bool isDark) {
    final isSelected = _streamMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _streamMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF3B30).withOpacity(0.15)
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF3B30) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF3B30) : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF3B30) : (isDark ? Colors.white : Colors.black),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundPicker(bool isDark, Color textPrimary, Color? textSecondary) {
    if (_loadingSounds) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final soundList = _soundTracks.isNotEmpty
        ? _soundTracks
        : [
            {'id': 1, 'title': 'Lofi Chill Beats', 'artist': 'Murih Vibes', 'category': 'Ambient'},
            {'id': 2, 'title': 'Upbeat Tech Energy', 'artist': 'CyberSound', 'category': 'Electronic'},
            {'id': 3, 'title': 'Acoustic Inspiration', 'artist': 'Studio A', 'category': 'Acoustic'},
          ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, color: Color(0xFFFF9500), size: 18),
              const SizedBox(width: 8),
              Text(
                _selectedSound != null
                    ? 'Active: ${_selectedSound!['title']} (${_selectedSound!['artist'] ?? ''})'
                    : 'Select Background Music / Theme Track',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: soundList.map((sound) {
                final isCurrent = _selectedSound?['id'] == sound['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedSound = isCurrent ? null : sound),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFFFF9500) : (isDark ? const Color(0xFF3A3A3C) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isCurrent ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                            size: 14, color: isCurrent ? Colors.white : const Color(0xFFFF9500)),
                        const SizedBox(width: 4),
                        Text(
                          sound['title']?.toString() ?? 'Track',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPicker(bool isDark, Color textPrimary, Color? textSecondary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: Color(0xFF34C759), size: 18),
              const SizedBox(width: 8),
              Text(
                _selectedProduct != null
                    ? 'Pinned: ${_selectedProduct!['title']}'
                    : 'Pin a product for viewers to purchase during stream',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _pinnedProducts.map((prod) {
                final isCurrent = _selectedProduct?['id'] == prod['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedProduct = isCurrent ? null : prod),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF34C759) : (isDark ? const Color(0xFF3A3A3C) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isCurrent ? Icons.check_circle_rounded : Icons.add_shopping_cart_rounded,
                            size: 14, color: isCurrent ? Colors.white : const Color(0xFF34C759)),
                        const SizedBox(width: 4),
                        Text(
                          '${prod['title']} (${prod['price']})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
