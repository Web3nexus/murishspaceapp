import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/permissions_service.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../screens/live_stream_screen.dart';
import 'kyc_live_gate_dialog.dart';

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
  bool _titleIsDefault = true;
  bool _settingDefaultTitle = false;

  // Dynamic Sound & Music Library
  List<Map<String, dynamic>> _soundTracks = [];
  Map<String, dynamic>? _selectedSound;
  bool _loadingSounds = true;

  // Sound preview playback while picking a track.
  AudioPlayer? _previewPlayer;
  dynamic _playingTrackId;

  // Dynamic Live Commerce Pinned Products
  List<Map<String, dynamic>> _pinnedProducts = [];
  Map<String, dynamic>? _selectedProduct;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _applyDefaultTitle();
    _fetchSoundTracks();
    _fetchProducts();

    _titleCtrl.addListener(() {
      if (!_settingDefaultTitle && _titleCtrl.text.trim().isNotEmpty) {
        _titleIsDefault = false;
      }
    });
  }

  void _applyDefaultTitle() {
    final community = widget.community?.name;
    final String text;
    if (_streamMode == 'meeting') {
      text = community != null ? 'Meeting in $community' : 'Meeting Room';
    } else if (_streamMode == 'audio') {
      text = community != null ? 'Audio in $community' : 'Audio Space';
    } else {
      text = community != null ? '🔴 Live: $community' : '🔴 Live Interactive Stream';
    }
    _settingDefaultTitle = true;
    _titleCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _settingDefaultTitle = false;
    _titleIsDefault = true;
  }

  void _handleModeChange(String mode) {
    setState(() => _streamMode = mode);
    if (mode == 'audio') setState(() => _cameraEnabled = false);
    if (_titleIsDefault || _titleCtrl.text.trim().isEmpty) _applyDefaultTitle();
  }

  @override
  void dispose() {
    _stopSoundPreview(silent: true);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSoundTracks() async {
    setState(() => _loadingSounds = true);
    try {
      final res = await ApiClient.instance.dio.get('/sound-tracks');
      final tracks = ApiClient.instance.unwrapList(res, (m) => m);
      if (mounted) {
        setState(() {
          _soundTracks = tracks;
          _loadingSounds = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _soundTracks = [];
          _loadingSounds = false;
        });
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _loadingProducts = true);
    try {
      // The creator/vendor's own listed products (physical + digital).
      final res = await ApiClient.instance.dio.get('/me/products');
      final products = ApiClient.instance.unwrapList(res, (m) => m);
      if (mounted) {
        setState(() {
          _pinnedProducts = products;
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pinnedProducts = [];
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _toggleSoundPreview(Map<String, dynamic> track) async {
    final audioUrl = ApiClient.resolveUrl(track['audio_url']?.toString());
    if (audioUrl == null || audioUrl.isEmpty) return;
    final id = track['id'];

    // Toggle off if this track is already playing.
    if (_previewPlayer != null && _playingTrackId == id) {
      await _stopSoundPreview();
      return;
    }

    await _stopSoundPreview();
    final player = AudioPlayer();
    _previewPlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(UrlSource(audioUrl));
      if (mounted) setState(() => _playingTrackId = id);
      player.onPlayerComplete.first.then((_) {
        if (mounted && _playingTrackId == id) {
          setState(() => _playingTrackId = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _playingTrackId = null);
    }
  }

  Future<void> _stopSoundPreview({bool silent = false}) async {
    final player = _previewPlayer;
    _previewPlayer = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
    if (!silent && mounted) setState(() => _playingTrackId = null);
  }

  String get _headerTitle {
    final community = widget.community?.name;
    return switch (_streamMode) {
      'meeting' => community != null ? 'Meeting in $community' : 'Start a Meeting',
      'audio' => community != null ? 'Audio Space in $community' : 'Start an Audio Space',
      _ => community != null ? 'Go Live in $community' : 'Go Live',
    };
  }

  String get _headerSubtitle {
    return switch (_streamMode) {
      'meeting' => 'Set up your meeting room & go live together',
      'audio' => 'Start a hands-free audio conversation',
      _ => 'Configure stream parameters & sell products',
    };
  }

  String get _modeBadgeLabel {
    return switch (_streamMode) {
      'meeting' => 'MEETING SETUP',
      'audio' => 'AUDIO SETUP',
      _ => 'LIVE SETUP',
    };
  }

  Color get _modeAccentColor {
    return switch (_streamMode) {
      'meeting' => const Color(0xFF007AFF),
      'audio' => const Color(0xFF34C759),
      _ => const Color(0xFFFF3B30),
    };
  }

  String get _ctaLabel {
    return switch (_streamMode) {
      'meeting' => 'Start Meeting',
      'audio' => 'Start Audio',
      _ => 'Go Live',
    };
  }

  IconData get _ctaIcon {
    return switch (_streamMode) {
      'meeting' => Icons.groups_rounded,
      'audio' => Icons.mic_rounded,
      _ => Icons.videocam_rounded,
    };
  }

  String get _titleHint {
    return switch (_streamMode) {
      'meeting' => 'e.g. Weekly Team Sync',
      'audio' => 'e.g. Community Hangout & Q&A',
      _ => 'e.g. Creator Strategy & Weekly Q&A',
    };
  }

  String _formatProductPrice(Map<String, dynamic> prod) {
    final symbol = prod['symbol']?.toString() ??
        (prod['currency'] == 'NGN' ? '₦' : (prod['currency'] == 'EUR' ? '€' : (prod['currency'] == 'GBP' ? '£' : '\$')));
    final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
    return '$symbol${price.toStringAsFixed(2)}';
  }

  String _formatDuration(Map<String, dynamic> track) {
    final raw = track['duration'] ?? track['duration_seconds'];
    final seconds = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startLive() async {
    final user = ref.read(authProvider).user;
    final kycStatus = user?.kycStatus.toLowerCase() ?? 'unsubmitted';
    if (kycStatus != 'verified' && kycStatus != 'approved') {
      Navigator.pop(context);
      showKycRequiredLiveModal(context);
      return;
    }

    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title for the broadcast.')),
      );
      return;
    }

    if (_cameraEnabled && _streamMode != 'audio') {
      await ref.read(permissionsProvider.notifier).ensureCamera(context);
    }
    if (_micEnabled) {
      await ref.read(permissionsProvider.notifier).ensureMicrophone(context);
    }

    if (!mounted) return;

    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          streamTitle: _titleCtrl.text.trim(),
          hostName: widget.community != null ? widget.community!.name : 'Creator Live',
          communityName: widget.community?.name,
          isHost: true,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headerTitle,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      Text(
                        _headerSubtitle,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _modeAccentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _streamMode == 'video'
                            ? Icons.fiber_manual_record_rounded
                            : (_streamMode == 'meeting' ? Icons.groups_rounded : Icons.mic_rounded),
                        color: _modeAccentColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _modeBadgeLabel,
                        style: TextStyle(color: _modeAccentColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
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
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              cursorColor: const Color(0xFF007AFF),
              decoration: InputDecoration(
                hintText: _titleHint,
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                prefixIcon: Icon(Icons.title_rounded, color: _modeAccentColor, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                ),
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
                : _soundTracks.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.library_music_outlined, color: Color(0xFFAF52DE), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No sound tracks yet. Tracks are managed from the admin sound library.',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _soundTracks.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final track = _soundTracks[idx];
                            final isSelected = _selectedSound?['id'] == track['id'];
                            final isPlaying = _playingTrackId == track['id'];
                            final hasAudio = (track['audio_url']?.toString() ?? '').isNotEmpty;
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
                                    if (hasAudio) ...[
                                      GestureDetector(
                                        onTap: () => _toggleSoundPreview(track),
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(color: Color(0xFFAF52DE), shape: BoxShape.circle),
                                          child: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(track['title']?.toString() ?? 'Track',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textPrimary)),
                                        Text(
                                          [track['artist']?.toString(), _formatDuration(track)].where((e) => (e ?? '').isNotEmpty).join(' · '),
                                          style: TextStyle(fontSize: 9, color: textSecondary),
                                        ),
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
                : _pinnedProducts.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined, color: Color(0xFFFF9500), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You haven\'t listed any products yet. Add products to your store to pin them to this stream.',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
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
                            final price = _formatProductPrice(prod);
                            final images = (prod['images'] as List?)?.whereType<String>().toList() ?? const <String>[];
                            final img = images.isNotEmpty ? images.first : (prod['cover_url']?.toString() ?? '');

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

            // Start Live / Meeting / Audio Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modeAccentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _startLive,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_ctaIcon, size: 20),
                    const SizedBox(width: 8),
                    Text(_ctaLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        onTap: () => _handleModeChange(mode),
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
