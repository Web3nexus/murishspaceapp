import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/online_status_badge.dart';
import '../core/design_tokens.dart';
import '../core/api_client.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/messages_provider.dart';
import '../models/story_models.dart';
import '../providers/story_provider.dart';
import '../services/sound_service.dart';
import 'call_screen.dart';
import 'story_viewer_screen.dart';

class ChatProfileSettingsScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final Conversation? initialConversation;

  const ChatProfileSettingsScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  ConsumerState<ChatProfileSettingsScreen> createState() => _ChatProfileSettingsScreenState();
}

class _ChatProfileSettingsScreenState extends ConsumerState<ChatProfileSettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isChatLocked = false;
  bool _isNotificationsEnabled = true;
  String _muteDuration = 'None';
  String _selectedSound = 'Default';
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isChatLocked = prefs.getBool('chat_locked_${widget.conversationId}') ?? false;
        _isNotificationsEnabled = !(widget.initialConversation?.isMuted ?? false);
      });
    }
  }

  Future<void> _toggleChatLock(bool enable) async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canAuth) {
        final didAuth = await _localAuth.authenticate(
          localizedReason: enable
              ? 'Authenticate to lock this conversation'
              : 'Authenticate to unlock this conversation',
          persistAcrossBackgrounding: true,
          biometricOnly: false,
        );
        if (!didAuth) return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_locked_${widget.conversationId}', enable);
      if (mounted) {
        setState(() => _isChatLocked = enable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable ? 'Chat locked with Biometrics / PIN' : 'Chat unlocked'),
            backgroundColor: enable ? const Color(0xFF007AFF) : Colors.grey[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update chat lock: $e')),
        );
      }
    }
  }

  Future<void> _toggleMute(bool enabled) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(conversationsProvider.notifier);
    await notifier.setSettings(widget.conversationId, muted: !enabled);
    if (mounted) {
      setState(() {
        _isNotificationsEnabled = enabled;
        if (enabled) _muteDuration = 'None';
      });
    }
  }

  void _showMuteDurationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mute Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded),
                title: const Text('Mute for 1 hour'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMute('1 Hour');
                },
              ),
              ListTile(
                leading: const Icon(Icons.nightlight_round),
                title: const Text('Mute for 8 hours'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMute('8 Hours');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Mute for 2 days'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMute('2 Days');
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_rounded, color: Colors.redAccent),
                title: const Text('Mute forever', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMute('Forever');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _setMute(String duration) {
    HapticFeedback.selectionClick();
    setState(() {
      _isNotificationsEnabled = false;
      _muteDuration = duration;
    });
    ref.read(conversationsProvider.notifier).setSettings(widget.conversationId, muted: true);
  }

  void _showNotificationSoundPicker() {
    final sounds = ['Default', 'Aurora', 'Chime', 'Bamboo', 'Glass', 'Pop'];
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Notification Sound'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: sounds.map((sound) {
                  final isSelected = _selectedSound == sound;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: sound,
                      groupValue: _selectedSound,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSound = val);
                          setDialogState(() {});
                          SoundService.instance.playNotificationPreview(val);
                        }
                      },
                    ),
                    title: Text(
                      sound,
                      style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF007AFF), size: 20),
                      tooltip: 'Preview sound',
                      onPressed: () {
                        SoundService.instance.playNotificationPreview(sound);
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedSound = sound);
                      setDialogState(() {});
                      SoundService.instance.playNotificationPreview(sound);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveContactModal(String name, String phone, String username) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Save Contact',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose where to save $name (@$username)',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF007AFF).withOpacity(0.12),
                    child: const Icon(Icons.contacts_rounded, color: Color(0xFF007AFF)),
                  ),
                  title: const Text('Save to Device Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export vCard (.vcf) directly to your phone contacts'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final vcard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:$name\r\nTEL;TYPE=CELL:$phone\r\nNOTE:MurihSpace @$username\r\nURL:https://murihspace.com/@$username\r\nEND:VCARD';
                    await Share.share(vcard, subject: '$name Contact Card');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9500).withOpacity(0.12),
                    child: const Icon(Icons.star_rounded, color: Color(0xFFFF9500)),
                  ),
                  title: const Text('Save to Murih Starred Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Quick-access in your Murih Space contacts tab'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('starred_user_${widget.conversationId}', true);
                    HapticFeedback.lightImpact();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF34C759).withOpacity(0.12),
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF34C759)),
                  ),
                  title: const Text('Copy Contact Details', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Copy full phone number and handle to clipboard'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(
                      text: 'Name: $name\nPhone: $phone\nUsername: @$username\nProfile: https://murihspace.com/@$username',
                    ));
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaGallery(List<Message> messages) {
    final mediaMessages = messages.where((m) => m.attachmentUrl != null && m.attachmentUrl!.isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DefaultTabController(
          length: 3,
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1E24) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const TabBar(
                  labelColor: DesignTokens.primary,
                  indicatorColor: DesignTokens.primary,
                  tabs: [
                    Tab(text: 'Media'),
                    Tab(text: 'Docs & Files'),
                    Tab(text: 'Links'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Media tab
                      mediaMessages.isEmpty
                          ? const Center(child: Text('No media shared yet.'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                              itemCount: mediaMessages.length,
                              itemBuilder: (context, index) {
                                final msg = mediaMessages[index];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: msg.attachmentUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey[300]),
                                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                  ),
                                );
                              },
                            ),
                      // Docs tab
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No files or documents shared yet.'),
                          ],
                        ),
                      ),
                      // Links tab
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No links shared yet.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createPrivateGroup(String contactName) {
    final titleController = TextEditingController(text: 'Group with $contactName');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Private Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create an end-to-end encrypted group containing you and $contactName.'),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final groupName = titleController.text.trim();
                Navigator.pop(ctx);
                if (groupName.isEmpty) return;

                try {
                  await ApiClient.instance.dio.post('/conversations/group', data: {
                    'title': groupName,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$groupName" created successfully!')),
                    );
                    ref.read(conversationsProvider.notifier).refresh();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Created private group "$groupName"')),
                    );
                  }
                }
              },
              child: const Text('Create Group'),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearChat() {
    bool alsoDeleteForRecipient = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Clear Chat History?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This will delete all messages in this chat. This action cannot be undone.'),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Also clear for recipient', style: TextStyle(fontSize: 14)),
                    value: alsoDeleteForRecipient,
                    onChanged: (val) {
                      setDialogState(() => alsoDeleteForRecipient = val ?? false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(conversationMessagesProvider(widget.conversationId).notifier)
                        .clearChat(forEveryone: alsoDeleteForRecipient);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat history cleared.')),
                      );
                    }
                  },
                  child: const Text('Clear Chat', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBlockUser(int userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Block $name?'),
          content: Text('$name will no longer be able to message you, call you, or see your online activity.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiClient.instance.dio.post('/users/$userId/block');
                  if (mounted) setState(() => _isBlocked = true);
                } catch (e) {
                  if (mounted) setState(() => _isBlocked = true);
                }
              },
              child: const Text('Block', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmUnblockUser(int userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Unblock $name?'),
          content: Text('$name will be able to message you and interact with you again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiClient.instance.dio.delete('/users/$userId/block');
                  if (mounted) setState(() => _isBlocked = false);
                } catch (e) {
                  if (mounted) setState(() => _isBlocked = false);
                }
              },
              child: const Text('Unblock', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMutualCommunitiesSheet(int userId, String name) async {
    if (userId == 0) return;

    // Show loading sheet first
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: () async {
            try {
              final res = await ApiClient.instance.dio.get('/users/$userId/mutual-communities');
              final raw = res.data;
              final List items = (raw is Map && raw.containsKey('data'))
                  ? (raw['data'] is List ? raw['data'] : [])
                  : (raw is List ? raw : []);
              return items.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
            } catch (_) {
              return <Map<String, dynamic>>[];
            }
          }(),
          builder: (ctx2, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final communities = snap.data ?? [];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      'Groups & Communities in Common with $name',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (communities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Text(
                        'No mutual groups or communities yet.',
                        style: TextStyle(color: DesignTokens.textSecondary),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: communities.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = communities[i];
                        final cName = c['name'] as String? ?? 'Unknown';
                        final tag = c['tag'] as String? ?? c['handle'] as String? ?? '';
                        final memberCount = c['member_count'] as int? ?? c['members_count'] as int? ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: DesignTokens.primarySoft,
                            child: const Icon(Icons.person, color: DesignTokens.primary, size: 22),
                          ),
                          title: Text(cName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: tag.isNotEmpty
                              ? Text('@$tag · $memberCount members', style: const TextStyle(fontSize: 12))
                              : Text('$memberCount members', style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: DesignTokens.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag.isNotEmpty ? '@$tag' : 'Community',
                              style: const TextStyle(fontSize: 11, color: DesignTokens.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReportSheet(int targetId, String targetName, bool isCommunity) {
    String selectedReason = 'spam';
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Report ${isCommunity ? 'Community' : targetName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Help us keep Murih Space safe. Select a reason:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    items: const [
                      DropdownMenuItem(value: 'spam', child: Text('Spam or Scam')),
                      DropdownMenuItem(value: 'harassment', child: Text('Harassment or Bullying')),
                      DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate Content / Violence')),
                      DropdownMenuItem(value: 'misinformation', child: Text('Misinformation / Impersonation')),
                      DropdownMenuItem(value: 'other', child: Text('Other Violation')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedReason = val);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Additional details (optional)...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await ApiClient.instance.dio.post('/reports', data: {
                            'reported_type': isCommunity ? 'post' : 'user',
                            'reported_id': targetId,
                            'reason': selectedReason,
                            'details': detailsController.text.trim(),
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thank you. Your report has been submitted.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report submitted successfully.')),
                            );
                          }
                        }
                      },
                      child: const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E222A) : Colors.white;

    // Get live conversation data
    final conversations = ref.watch(conversationsProvider).conversations;
    final conversation = conversations.where((c) => c.id == widget.conversationId).firstOrNull ??
        widget.initialConversation;

    final messagesState = ref.watch(conversationMessagesProvider(widget.conversationId));
    final mediaCount = messagesState.messages.where((m) => m.attachmentUrl?.isNotEmpty == true).length;

    final isCommunity = conversation?.type == 'community';
    final otherUser = conversation?.otherUser;
    final title = conversation?.title ?? otherUser?.name ?? 'Contact Details';
    final username = otherUser?.username.isNotEmpty == true ? otherUser!.username : 'user_${widget.conversationId}';
    final avatar = conversation?.avatarUrl ?? '';
    const phone = '+234 812 000 1122';
    const bio = 'Digital Creator & Web3 Innovator · Murih Space Active Member ✨';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121418) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: Text(isCommunity ? 'Community Info' : 'Contact Info'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (isCommunity) return;
                    final storyState = ref.read(storyProvider);
                    UserStoryGroup? matched;
                    for (final g in storyState.groups) {
                      if (g.userId == otherUser?.id.toString() ||
                          g.userName.toLowerCase() == (otherUser?.name ?? title).toLowerCase()) {
                        matched = g;
                        break;
                      }
                    }
                    final activeStories = matched?.stories.where((s) => !s.isExpired).toList() ?? [];
                    if (activeStories.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(group: matched!.copyWith(stories: activeStories)),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No active 24h stories from $title today.')),
                      );
                    }
                  },
                  child: OnlineAvatarBadge(
                    isOnline: !isCommunity,
                    badgeSize: 16,
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: DesignTokens.primarySoft,
                      backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person, color: DesignTokens.primaryDark, size: 50)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                if (!isCommunity)
                  Text(
                    '@$username',
                    style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 14),
                  )
                else
                  Text(
                    '${conversation?.memberCount ?? 120} members · Community',
                    style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 14),
                  ),
                const SizedBox(height: 16),
                // Quick Actions: Audio Call, Video Call, Mute, Search
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickActionButton(
                      icon: Icons.call_rounded,
                      label: 'Audio',
                      color: const Color(0xFF34C759),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              contactName: title,
                              phoneNumber: phone,
                              avatarUrl: avatar,
                              isVideo: false,
                            ),
                          ),
                        );
                      },
                    ),
                    _QuickActionButton(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      color: const Color(0xFF007AFF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              contactName: title,
                              phoneNumber: phone,
                              avatarUrl: avatar,
                              isVideo: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _QuickActionButton(
                      icon: _isNotificationsEnabled ? Icons.notifications_none_rounded : Icons.notifications_off_rounded,
                      label: _isNotificationsEnabled ? 'Mute' : 'Unmute',
                      color: _isNotificationsEnabled ? const Color(0xFFFF9500) : Colors.grey,
                      onTap: () {
                        if (_isNotificationsEnabled) {
                          _showMuteDurationSheet();
                        } else {
                          _toggleMute(true);
                        }
                      },
                    ),
                    _QuickActionButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Save',
                      color: const Color(0xFF5856D6),
                      onTap: () => _showSaveContactModal(title, phone, username),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contact Info Details
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    isCommunity ? 'ABOUT COMMUNITY' : 'CONTACT DETAILS',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.textSecondary),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: DesignTokens.primary),
                  title: const Text('Bio', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                  subtitle: const Text(bio, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: bio));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio copied to clipboard!')));
                  },
                ),
                const Divider(height: 1),
                if (!isCommunity) ...[
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded, color: DesignTokens.primary),
                    title: const Text('Username', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                    subtitle: Text('@$username', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.copy_rounded, size: 18),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '@$username'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username copied!')));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_rounded, color: DesignTokens.primary),
                    title: const Text('Mobile', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                    subtitle: const Text(phone, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF34C759)),
                    onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Media & Shared Content
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF007AFF)),
              title: const Text('Media, Links & Docs', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('$mediaCount shared items'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showMediaGallery(messagesState.messages),
            ),
          ),
          const SizedBox(height: 12),

          // Notifications & Security
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'NOTIFICATIONS & PRIVACY',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.textSecondary),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFFFF9500)),
                  title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_isNotificationsEnabled ? 'Active' : 'Muted ($_muteDuration)'),
                  value: _isNotificationsEnabled,
                  onChanged: (val) {
                    if (val) {
                      _toggleMute(true);
                    } else {
                      _showMuteDurationSheet();
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.music_note_rounded, color: Color(0xFFFF2D55)),
                  title: const Text('Notification Sound'),
                  subtitle: Text(_selectedSound),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showNotificationSoundPicker,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline_rounded, color: Color(0xFF34C759)),
                  title: const Text('Lock Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Require Face ID / Touch ID / PIN to open'),
                  value: _isChatLocked,
                  onChanged: _toggleChatLock,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Community & Social Actions
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'COMMUNITY & NETWORKING',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.textSecondary),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined, color: Color(0xFF5856D6)),
                  title: Text('Create Private Group with $title'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _createPrivateGroup(title),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.diversity_3_outlined, color: DesignTokens.primary),
                  title: const Text('Groups & Communities in Common'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showMutualCommunitiesSheet(otherUser?.id ?? 0, title),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // The Red Zone
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'RED ZONE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                  title: const Text('Clear Chat History', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  onTap: _confirmClearChat,
                ),
                const Divider(height: 1),
                if (!isCommunity) ...[
                  ListTile(
                    leading: Icon(
                      _isBlocked ? Icons.lock_open_rounded : Icons.block_flipped,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      _isBlocked ? 'Unblock $title' : 'Block $title',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _isBlocked
                        ? _confirmUnblockUser(otherUser?.id ?? widget.conversationId, title)
                        : _confirmBlockUser(otherUser?.id ?? widget.conversationId, title),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: Text('Report ${isCommunity ? 'Community' : title}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () => _showReportSheet(otherUser?.id ?? widget.conversationId, title, isCommunity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

