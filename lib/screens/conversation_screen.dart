import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../components/app_bottom_sheet.dart';
import '../components/online_status_badge.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/calls_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/realtime_provider.dart';
import 'call_screen.dart';
import 'conversation_composer.dart';
import 'message_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final int conversationId;

  const ConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  bool _subscribed = false;
  bool _uploading = false;
  bool _wasComposing = false;

  XFile? _pendingImage;
  Message? _replyTo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_subscribed) {
      _subscribed = true;
      ref.read(realtimeProvider).enterConversation(widget.conversationId);
    }
  }

  /// Rebuilds the composer (send button enabled state) and fires the typing
  /// event only when starting/stopping a message.
  void _handleComposerChange() {
    final composing = _controller.text.trim().isNotEmpty;
    if (composing != _wasComposing) {
      _wasComposing = composing;
      ref.read(conversationMessagesProvider(widget.conversationId).notifier).sendTyping(composing);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleComposerChange);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) setState(() => _pendingImage = file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo library.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final image = _pendingImage;
    final replyToId = _replyTo?.id;
    if (text.isEmpty && image == null) return;

    // Clear optimistically so the composer feels instant.
    _controller.clear();
    setState(() => _replyTo = null);
    _scrollToBottom();

    final notifier = ref.read(conversationMessagesProvider(widget.conversationId).notifier);
    notifier.sendTyping(false);

    if (image != null) {
      setState(() => _uploading = true);
      try {
        final upload = await _uploadAttachment(image);
        await notifier.sendMessage(
          content: text,
          replyToId: replyToId,
          mediaId: upload.$1,
          attachmentUrl: upload.$2,
          attachmentType: upload.$3,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment upload failed. Please try again.')),
          );
        }
        setState(() => _uploading = false);
        return;
      }
      setState(() {
        _uploading = false;
        _pendingImage = null;
      });
    } else {
      await notifier.sendMessage(content: text, replyToId: replyToId);
    }
  }

  Future<(int, String, String)> _uploadAttachment(XFile file) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
      'client_uuid': ApiClient.generateIdempotencyKey(),
    });
    final response = await ApiClient.instance.dio.post('/messages/attachments', data: form);
    final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
    return (
      (payload['media_id'] as num).toInt(),
      payload['attachment_url'] as String,
      payload['attachment_type'] as String,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationMessagesProvider(widget.conversationId));
    final typing = ref.watch(typingProvider)[widget.conversationId] ?? const {};

    final conversation = ref
        .watch(conversationsProvider)
        .conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final isEscrowActive = conversation?.hasActiveEscrow ?? false;
    final escrowAmountText = conversation?.escrowAmount != null
        ? '${conversation!.escrowCurrency ?? '\$'} ${conversation.escrowAmount!.toStringAsFixed(2)} LOCKED'
        : 'FUNDS LOCKED IN ESCROW';

    return Scaffold(
      appBar: AppBar(
        title: _ConversationTitle(conversationId: widget.conversationId),
        actions: [
          IconButton(
            onPressed: () {
              final title = conversation?.otherUser?.name ?? (conversation?.title.isNotEmpty == true ? conversation!.title : 'Contact');
              final avatar = conversation?.otherUser?.avatarUrl ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    contactName: title,
                    phoneNumber: '+234 812 000 1122',
                    avatarUrl: avatar,
                    isVideo: false,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.call_rounded, color: Color(0xFF34C759)),
            tooltip: 'Voice Call',
          ),
          IconButton(
            onPressed: () {
              final title = conversation?.otherUser?.name ?? (conversation?.title.isNotEmpty == true ? conversation!.title : 'Contact');
              final avatar = conversation?.otherUser?.avatarUrl ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    contactName: title,
                    phoneNumber: '+234 812 000 1122',
                    avatarUrl: avatar,
                    isVideo: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Video Call',
          ),
          IconButton(
            onPressed: () => _openChatMenu(),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isEscrowActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔒 ESCROW TRANSACTION ACTIVE · $escrowAmountText',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Text(
                          'Auto-Tagged: #Business: Escrow Deal · Messages preserved until release',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _messageArea(state, typing)),
          Composer(
            controller: _controller,
            replyTo: _replyTo,
            pendingImage: _pendingImage,
            uploading: _uploading,
            canSend: _controller.text.trim().isNotEmpty || _pendingImage != null,
            onPickImage: _pickImage,
            onDismissReply: () => setState(() => _replyTo = null),
            onDismissImage: () => setState(() => _pendingImage = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _messageArea(ConversationMessagesState state, Map<int, TypingInfo> typing) {
    if (state.loading && state.messages.isEmpty) {
      return const LoadingStateWidget(message: 'Loading messages…');
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load messages',
        description: state.error!,
        onRetry: () => ref.read(conversationMessagesProvider(widget.conversationId).notifier).retry(),
      );
    }

    final messages = state.messages.reversed.toList();
    final typer = typing.values.isNotEmpty ? typing.values.first : null;
    final showTopLoader = state.hasMore;
    final itemCount = messages.length + (typer != null ? 1 : 0) + (showTopLoader ? 1 : 0);
    final conversation = ref
        .read(conversationsProvider)
        .conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final isGroup = conversation?.type == 'community';

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // With `reverse`, index 0 is the newest message at the bottom.
        // Layout bottom→top: [typer?, messages…, topLoader?]
        if (i == messages.length && typer != null) {
          return _TypingBubble(name: typer.userName);
        }
        if (i == messages.length + (typer != null ? 1 : 0)) {
          return _topLoader(state);
        }
        return MessageBubble(
          message: messages[i],
          myId: ref.watch(authProvider).user?.id,
          showSenderName: isGroup,
          onReact: (emoji) => _toggleReaction(messages[i], emoji),
          onReply: () => setState(() => _replyTo = messages[i]),
          onDelete: (forEveryone) => _deleteMessage(messages[i], forEveryone),
          onForward: () => _forwardMessage(messages[i]),
          onRetry: messages[i].status == 'failed'
              ? () => ref.read(conversationMessagesProvider(widget.conversationId).notifier)
                    .retrySending(messages[i])
              : null,
        );
      },
    );
  }

  Widget _topLoader(ConversationMessagesState state) {
    if (!state.hasMore) return const SizedBox(height: 4);
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return InkWell(
      onTap: () => ref.read(conversationMessagesProvider(widget.conversationId).notifier).loadMore(),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Center(
          child: Text('Load earlier messages', style: TextStyle(color: DesignTokens.primaryDark)),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(Message message, String emoji) async {
    await ref
        .read(conversationMessagesProvider(widget.conversationId).notifier)
        .toggleReaction(message.id, emoji);
  }

  Future<void> _deleteMessage(Message message, bool forEveryone) async {
    final conversation = ref
        .read(conversationsProvider)
        .conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final isEscrowActive = conversation?.hasActiveEscrow ?? false;
    if (isEscrowActive) {
      await AppBottomSheet.showNotice(
        context: context,
        title: 'Messages Locked',
        message: 'Messages in active Escrow transactions or Brand Deals cannot be deleted until all funds are released or closed.',
        actionText: 'Understood',
        icon: Icons.lock_rounded,
      );
      return;
    }

    await ref
        .read(conversationMessagesProvider(widget.conversationId).notifier)
        .deleteMessage(message.id, forEveryone: forEveryone);
  }

  Future<void> _forwardMessage(Message message) async {
    final conversations = ref.read(conversationsProvider).conversations;
    if (conversations.isEmpty) return;
    final target = await showModalBottomSheet<Conversation>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => _ForwardSheet(conversations: conversations),
    );
    if (target == null) return;
    try {
      await ApiClient.instance.dio.post(
        '/messages/${message.id}/forward',
        data: {
          'to_conversation_id': target.id,
          'client_uuid': ApiClient.generateIdempotencyKey(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message forwarded')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not forward this message.')),
        );
      }
    }
  }

  void _openChatMenu() {
    final notifier = ref.read(conversationsProvider.notifier);
    final conversation = ref
        .read(conversationsProvider)
        .conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final isMuted = conversation?.isMuted ?? false;
    final isArchived = conversation?.isArchived ?? false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isMuted ? Icons.volume_up_outlined : Icons.notifications_off_outlined),
              title: Text(isMuted ? 'Unmute notifications' : 'Mute notifications'),
              onTap: () {
                Navigator.pop(context);
                notifier.setSettings(widget.conversationId, muted: !isMuted);
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(isArchived ? 'Unarchive chat' : 'Archive chat'),
              onTap: () {
                Navigator.pop(context);
                notifier.setSettings(widget.conversationId, archived: !isArchived);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ConversationTitle extends ConsumerWidget {
  final int conversationId;

  const _ConversationTitle({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider).conversations;
    Conversation? conversation;
    for (final c in conversations) {
      if (c.id == conversationId) {
        conversation = c;
        break;
      }
    }
    final title = conversation?.title ?? 'Chat';
    final avatar = conversation?.avatarUrl;
    final isCommunity = conversation?.type == 'community';
    final memberCount = conversation?.memberCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnlineAvatarBadge(
          isOnline: !isCommunity,
          badgeSize: 10,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: DesignTokens.primarySoft,
            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty
                ? Text(
                    title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700, fontSize: 14),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (isCommunity)
                Text(
                  memberCount == null ? 'Community' : 'Community · $memberCount members',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                )
              else
                const OnlineStatusBadge(isOnline: true, showLabel: true, dotSize: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final String name;

  const _TypingBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _TypingDots(),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'typing…',
                style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Dot(size: 6),
          _Dot(size: 6),
          _Dot(size: 6),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;

  const _Dot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: DesignTokens.textSecondary,
      ),
    );
  }
}

class _ForwardSheet extends StatelessWidget {
  final List<Conversation> conversations;

  const _ForwardSheet({required this.conversations});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Forward to',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final c = conversations[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: DesignTokens.primarySoft,
                    backgroundImage:
                        c.avatarUrl != null && c.avatarUrl!.isNotEmpty ? NetworkImage(c.avatarUrl!) : null,
                    child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                        ? Text(
                            c.initials,
                            style: const TextStyle(
                              color: DesignTokens.primaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          )
                        : null,
                  ),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
