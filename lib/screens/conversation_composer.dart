import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import 'community_create_dialog.dart';

/// Telegram-style capsule message composer with roll-up attachment sheet.
class Composer extends StatelessWidget {
  final TextEditingController controller;
  final Message? replyTo;
  final XFile? pendingImage;
  final bool uploading;
  final bool canSend;
  final VoidCallback onPickImage;
  final VoidCallback onDismissReply;
  final VoidCallback onDismissImage;
  final VoidCallback onSend;

  const Composer({
    super.key,
    required this.controller,
    this.replyTo,
    this.pendingImage,
    this.uploading = false,
    required this.canSend,
    required this.onPickImage,
    required this.onDismissReply,
    required this.onDismissImage,
    required this.onSend,
  });

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TelegramAttachmentSheet(
        onPickImage: () {
          Navigator.pop(ctx);
          onPickImage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final inputBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFF3F6);

    return Container(
      color: bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTo != null) _ReplyBar(message: replyTo!, onDismiss: onDismissReply),
            if (pendingImage != null) _ImagePreview(file: pendingImage!, onDismiss: onDismissImage),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Telegram attachment paperclip button
                  IconButton(
                    onPressed: uploading ? null : () => _showAttachmentSheet(context),
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                      size: 24,
                    ),
                    tooltip: 'Attachments',
                  ),
                  // Capsule text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 15,
                              ),
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) {
                                if (canSend) onSend();
                              },
                              decoration: InputDecoration(
                                hintText: 'Message…',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dynamic send / voice mic button
                  uploading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF007AFF),
                          ),
                          child: IconButton(
                            onPressed: canSend ? onSend : null,
                            icon: Icon(
                              canSend ? Icons.send_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramAttachmentSheet extends StatelessWidget {
  final VoidCallback onPickImage;

  const _TelegramAttachmentSheet({required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final actions = [
      _AttachmentAction('Gallery', Icons.photo_library_rounded, const Color(0xFF007AFF), onPickImage),
      _AttachmentAction('Poll', Icons.poll_rounded, const Color(0xFFFF9500), () {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Poll feature available in group chats')),
        );
      }),
      _AttachmentAction('Community', Icons.group_add_rounded, const Color(0xFF34C759), () {
        navigator.pop();
        showCreateCommunityDialog(context);
      }),
      _AttachmentAction('Gift', Icons.card_giftcard_rounded, const Color(0xFFFF2D55), () {
        navigator.pop();
        router.push('/gifts');
      }),
      _AttachmentAction('Wallet', Icons.account_balance_wallet_rounded, const Color(0xFF5856D6), () {
        navigator.pop();
        router.push('/wallet');
      }),
      _AttachmentAction('Location', Icons.location_on_rounded, const Color(0xFFFFCC00), () {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Location sharing ready')),
        );
      }),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Share content or create',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (ctx, i) {
                final item = actions[i];
                return InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _AttachmentAction(this.title, this.icon, this.color, this.onTap);
}

class _ReplyBar extends StatelessWidget {
  final Message message;
  final VoidCallback onDismiss;

  const _ReplyBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = message.attachmentType != null && message.attachmentType != 'text'
        ? message.attachmentType == 'image'
            ? 'Photo'
            : message.attachmentType!
        : message.content;
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F5F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: Color(0xFF007AFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.user?.name ?? 'Replying',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : const Color(0xFF61758A),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onDismiss;

  const _ImagePreview({required this.file, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F5F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(file.path),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photo',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : const Color(0xFF61758A),
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
