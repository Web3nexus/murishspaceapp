import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/design_tokens.dart';
import '../models/chat_models.dart';

/// Message composer: attach image, reply preview, text field and send button.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo != null) _ReplyBar(message: replyTo!, onDismiss: onDismissReply),
          if (pendingImage != null) _ImagePreview(file: pendingImage!, onDismiss: onDismissImage),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: DesignTokens.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: uploading ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined, color: DesignTokens.primaryDark),
                  tooltip: 'Attach photo',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) {
                      if (canSend) onSend();
                    },
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: const TextStyle(color: DesignTokens.textSecondary),
                      filled: true,
                      fillColor: const Color(0xFFF2F5F8),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                uploading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _SendButton(enabled: canSend, onSend: onSend),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSend;

  const _SendButton({required this.enabled, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: enabled ? onSend : null,
      style: IconButton.styleFrom(backgroundColor: DesignTokens.primary),
      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final Message message;
  final VoidCallback onDismiss;

  const _ReplyBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final preview = message.attachmentType != null && message.attachmentType != 'text'
        ? message.attachmentType == 'image'
            ? 'Photo'
            : message.attachmentType!
        : message.content;
    return Container(
      color: const Color(0xFFF2F5F8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: DesignTokens.primaryDark),
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
                    color: DesignTokens.primaryDark,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
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
    return Container(
      color: const Color(0xFFF2F5F8),
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
          const Expanded(
            child: Text(
              'Photo',
              style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
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
