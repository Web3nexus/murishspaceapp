import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_toast.dart';
import '../core/api_client.dart';
import '../services/sound_service.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _showOnlineStatus = true;
  bool _readReceiptsEnabled = true;
  bool _chatSoundsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/settings/chat');
      final data = res.data is Map ? res.data['data'] ?? res.data : null;

      final soundsLocal = await SoundService.instance.isSoundEnabled();

      if (mounted && data != null) {
        setState(() {
          _showOnlineStatus = (data['show_online_status'] as bool?) ?? true;
          _readReceiptsEnabled = (data['read_receipts_enabled'] as bool?) ?? true;
          _chatSoundsEnabled = (data['chat_sounds_enabled'] as bool?) ?? soundsLocal;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _chatSoundsEnabled = soundsLocal;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final soundsLocal = await SoundService.instance.isSoundEnabled();
        setState(() {
          _chatSoundsEnabled = soundsLocal;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting({
    bool? showOnline,
    bool? readReceipts,
    bool? chatSounds,
  }) async {
    final newOnline = showOnline ?? _showOnlineStatus;
    final newReceipts = readReceipts ?? _readReceiptsEnabled;
    final newSounds = chatSounds ?? _chatSoundsEnabled;

    setState(() {
      _showOnlineStatus = newOnline;
      _readReceiptsEnabled = newReceipts;
      _chatSoundsEnabled = newSounds;
      _isSaving = true;
    });

    if (chatSounds != null) {
      await SoundService.instance.setSoundEnabled(newSounds);
      if (newSounds) {
        await SoundService.instance.playMessageReceived();
      }
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.put(
        '/settings/chat',
        data: {
          'show_online_status': newOnline,
          'read_receipts_enabled': newReceipts,
          'chat_sounds_enabled': newSounds,
        },
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to save setting. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Chat & Messaging Settings',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Privacy & Presence Group ──────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Show Online Status
                      SwitchListTile.adaptive(
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.circle,
                              size: 14,
                              color: Color(0xFF34C759),
                            ),
                          ),
                        ),
                        title: Text(
                          'Show Online Status',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'When on, others see a green dot when you are active. When off, you appear offline.',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        value: _showOnlineStatus,
                        activeColor: const Color(0xFF34C759),
                        onChanged: (val) => _updateSetting(showOnline: val),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),

                      // Read Receipts
                      SwitchListTile.adaptive(
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.done_all_rounded,
                              size: 20,
                              color: Color(0xFF34C759),
                            ),
                          ),
                        ),
                        title: Text(
                          'Read Receipts',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Send two green checkmarks (✓✓) when you read messages. When off, your reads stay private.',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        value: _readReceiptsEnabled,
                        activeColor: const Color(0xFF34C759),
                        onChanged: (val) => _updateSetting(readReceipts: val),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),

                      // Message & Notification Sounds
                      SwitchListTile.adaptive(
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 20,
                              color: Color(0xFFFF9500),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Chat & Notification Sounds',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_chatSoundsEnabled)
                              GestureDetector(
                                onTap: () => SoundService.instance.playMessageReceived(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'Test',
                                    style: TextStyle(
                                      color: Color(0xFF007AFF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'Play audio alerts when new messages or notifications arrive.',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        value: _chatSoundsEnabled,
                        activeColor: const Color(0xFF34C759),
                        onChanged: (val) => _updateSetting(chatSounds: val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Info / Visual Legend Card ────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Read Receipts Guide',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.done_rounded, size: 18, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            'One grey check: Sent to server',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.done_all_rounded, size: 18, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            'Two grey checks: Delivered to recipient',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF34C759)),
                          const SizedBox(width: 10),
                          Text(
                            'Two green checks: Read by recipient',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
