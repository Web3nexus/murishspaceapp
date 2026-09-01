import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_bottom_sheet.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../utils/format.dart';

/// One chat bubble with reactions, status and long-press actions.
class MessageBubble extends StatelessWidget {
  final Message message;
  final int? myId;
  final bool showSenderName;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final ValueChanged<bool> onDelete;
  final VoidCallback onForward;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.myId,
    this.showSenderName = true,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    required this.onForward,
    this.onRetry,
  });

  bool get _mine => message.userId == myId;

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final showName = !mine && showSenderName && message.user?.name != null && message.user!.name.isNotEmpty;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName) _SenderName(name: message.user!.name),
          GestureDetector(
            onLongPress: () => _showActions(context),
            onTap: () => _showReactions(context),
            child: _BubbleContent(message: message, mine: mine),
          ),
          if (message.reactions.isNotEmpty)
            _ReactionChips(reactions: message.reactions, onToggle: onReact),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Message actions',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final emoji in _emojis)
                    _EmojiAction(emoji: emoji, onTap: () => Navigator.pop(context, 'react:$emoji')),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            if (!message.deleted)
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (!message.deleted)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(
                  message.userId == myId ? 'Delete' : 'Delete for me',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'reply':
        onReply();
      case 'forward':
        onForward();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
      case 'delete':
        await _confirmDelete(context);
      default:
        if (action.startsWith('react:')) onReact(action.substring('react:'.length));
    }
  }

  Future<void> _showReactions(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final emoji in _emojis)
                InkWell(
                  onTap: () => Navigator.pop(context, emoji),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onReact(result);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final mine = message.userId == myId;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
        final textPrimary = isDark ? DesignTokens.darkTextPrimary : DesignTokens.lightTextPrimary;
        final textSecondary = isDark ? DesignTokens.darkTextSecondary : DesignTokens.lightTextSecondary;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mine ? 'Delete this message for everyone, or only for you?' : 'Delete this message for you?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 20),
              if (mine) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, 'everyone'),
                    child: const Text('Delete for Everyone', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isDark ? DesignTokens.darkBorder : DesignTokens.lightBorder),
                  ),
                  onPressed: () => Navigator.pop(ctx, 'me'),
                  child: Text(mine ? 'Delete for Me' : 'Delete', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancel', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    if (choice == 'me') onDelete(false);
    if (choice == 'everyone') onDelete(true);
  }
}

class _SenderName extends StatelessWidget {
  final String name;

  const _SenderName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 2),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: DesignTokens.primaryDark,
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  final Message message;
  final bool mine;

  const _BubbleContent({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final Color bubbleColor = mine
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF1C1C1E) : Colors.white);
    final Color textColor = mine
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: message.hasAttachment && message.isImage
          ? const EdgeInsets.all(3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine
            ? null
            : Border.all(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                width: 0.8,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyTo != null) _ReplyPreview(message: message.replyTo!, mine: mine),
          if (message.hasAttachment && message.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CachedNetworkImage(
                imageUrl: message.attachmentUrl!,
                width: maxWidth - 8,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 220,
                  height: 160,
                  color: mine ? const Color(0xFF2E5A78) : const Color(0xFFF2F5F8),
                  child: const Icon(Icons.broken_image_outlined, color: Colors.white70),
                ),
                placeholder: (_, __) => Container(
                  width: 220,
                  height: 160,
                  color: mine ? const Color(0xFF2E5A78) : const Color(0xFFF2F5F8),
                ),
              ),
            )
          else if (message.isVoice)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: mine ? Colors.white : const Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text('Voice message', style: TextStyle(color: textColor)),
              ],
            )
          else if (!message.deleted)
            Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
            ),
          if (message.deleted)
            Text(
              'This message was deleted',
              style: TextStyle(color: textColor.withOpacity(0.8), fontStyle: FontStyle.italic),
            ),
          _MetaRow(message: message, mine: mine),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Message message;
  final bool mine;

  const _ReplyPreview({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final borderColor = mine ? Colors.white54 : DesignTokens.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.user?.name ?? 'Message',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mine ? Colors.white : DesignTokens.primaryDark,
            ),
          ),
          Text(
            message.attachmentType == 'image' ? 'Photo' : message.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: mine ? Colors.white70 : DesignTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Message message;
  final bool mine;

  const _MetaRow({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyTo != null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.reply, size: 12, color: Colors.white70),
            ),
          if (message.forwardedFromMessageId != null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.forward, size: 12, color: Colors.white70),
            ),
          Text(
            formatMessageTime(message.createdAt),
            style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : DesignTokens.textSecondary),
          ),
          if (mine) ...[
            const SizedBox(width: 4),
            if (message.status == 'sending')
              const Icon(Icons.schedule, size: 12, color: Colors.white70)
            else if (message.status == 'failed')
              Icon(Icons.error_outline, size: 13, color: mine ? const Color(0xFFFFB4B4) : Theme.of(context).colorScheme.error)
            else if (message.read)
              const Icon(Icons.done_all, size: 13, color: Color(0xFF9BE0FF))
            else
              const Icon(Icons.done, size: 13, color: Colors.white70),
          ],
        ],
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  final List<ReactionSummary> reactions;
  final ValueChanged<String> onToggle;

  const _ReactionChips({required this.reactions, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: [
          for (final r in reactions)
            InkWell(
              onTap: () => onToggle(r.emoji),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.byMe
                      ? const Color(0xFF007AFF).withOpacity(0.15)
                      : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: r.byMe
                        ? const Color(0xFF007AFF)
                        : (isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA)),
                  ),
                ),
                child: Text(
                  '${r.emoji} ${r.count}',
                  style: TextStyle(
                    fontSize: 12,
                    color: r.byMe
                        ? const Color(0xFF007AFF)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiAction extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiAction({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
