import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../components/create_poll_sheet.dart';
import '../components/emoji_picker_sheet.dart';
import '../components/share_community_sheet.dart';
import '../components/share_location_sheet.dart';
import '../components/wallet_sheet.dart';
import '../models/chat_models.dart';

/// Telegram-style capsule message composer with roll-up attachment sheet
/// and WhatsApp-style audio voice recording.
class Composer extends StatefulWidget {
  final TextEditingController controller;
  final Message? replyTo;
  final XFile? pendingImage;
  final bool uploading;
  final bool canSend;
  final VoidCallback onPickImage;
  final VoidCallback? onPickCamera;
  final VoidCallback onDismissReply;
  final VoidCallback onDismissImage;
  final VoidCallback onSend;
  final ValueChanged<Map<String, dynamic>>? onSendPoll;
  final VoidCallback? onSendGift;
  final void Function(File audioFile, int durationSeconds)? onSendVoice;
  final ValueChanged<CommunityShareItem>? onShareCommunity;
  final ValueChanged<LocationShareData>? onShareLocation;

  const Composer({
    super.key,
    required this.controller,
    this.replyTo,
    this.pendingImage,
    this.uploading = false,
    required this.canSend,
    required this.onPickImage,
    this.onPickCamera,
    required this.onDismissReply,
    required this.onDismissImage,
    required this.onSend,
    this.onSendPoll,
    this.onSendGift,
    this.onSendVoice,
    this.onShareCommunity,
    this.onShareLocation,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _currentRecordingPath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record voice messages.')),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: path,
      );

      HapticFeedback.mediumImpact();

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _currentRecordingPath = path;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start voice recording.')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.cancel();
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}

    HapticFeedback.lightImpact();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _currentRecordingPath = null;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final duration = _recordSeconds;

    try {
      final path = await _audioRecorder.stop();
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
          _currentRecordingPath = null;
        });
      }

      if (path != null && duration >= 1) {
        final file = File(path);
        if (await file.exists() && widget.onSendVoice != null) {
          widget.onSendVoice!(file, duration);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold to record a voice message.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
        });
      }
    }
  }

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
          widget.onPickImage();
        },
        onPickCamera: widget.onPickCamera != null
            ? () {
                Navigator.pop(ctx);
                widget.onPickCamera!();
              }
            : null,
        onSendPoll: widget.onSendPoll,
        onSendGift: widget.onSendGift,
        onShareCommunity: widget.onShareCommunity,
        onShareLocation: widget.onShareLocation,
      ),
    );
  }

  String _formatRecordTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181A20) : Colors.white;
    final inputBg = isDark ? const Color(0xFF222630) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) _ReplyBar(message: widget.replyTo!, onDismiss: widget.onDismissReply),
            if (widget.pendingImage != null) _ImagePreview(file: widget.pendingImage!, onDismiss: widget.onDismissImage),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _isRecording
                  ? _buildRecordingBar(isDark)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Telegram attachment paperclip button
                        IconButton(
                          onPressed: widget.uploading ? null : () => _showAttachmentSheet(context),
                          icon: Icon(
                            Icons.attach_file_rounded,
                            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                            size: 24,
                          ),
                          tooltip: 'Attachments',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        // Quick Camera capture button beside the input field
                        if (widget.onPickCamera != null)
                          IconButton(
                            onPressed: widget.uploading ? null : widget.onPickCamera,
                            icon: Icon(
                              Icons.camera_alt_rounded,
                              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                              size: 24,
                            ),
                            tooltip: 'Take Photo',
                            padding: const EdgeInsets.only(left: 4, right: 6, bottom: 8, top: 8),
                            constraints: const BoxConstraints(),
                          ),
                        // Capsule text field with modern curved radius
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark ? const Color(0xFF323846) : const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: widget.controller,
                                    minLines: 1,
                                    maxLines: 5,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 15,
                                    ),
                                    textInputAction: TextInputAction.newline,
                                    onSubmitted: (_) {
                                      if (widget.canSend) widget.onSend();
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
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openEmojiPicker(context),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    child: Icon(
                                      Icons.sentiment_satisfied_alt_rounded,
                                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Dynamic send / voice mic button
                        widget.uploading
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
                                  onPressed: widget.canSend ? widget.onSend : _startRecording,
                                  icon: Icon(
                                    widget.canSend ? Icons.send_rounded : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: widget.canSend ? 'Send' : 'Hold or Tap to Record',
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

  Widget _buildRecordingBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222630) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Blinking red record dot
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Timer
          Text(
            _formatRecordTime(_recordSeconds),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          // Integrated live Sound Waveform equalizer
          Expanded(
            child: Center(
              child: _AudioRecordingWaveform(
                animation: _pulseController,
                isDark: isDark,
              ),
            ),
          ),
          // Explicit Cancel / Discard button
          InkWell(
            onTap: _cancelRecording,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 16),
                  SizedBox(width: 3),
                  Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Stop & Send
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF007AFF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _stopAndSendRecording,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
              tooltip: 'Send voice message',
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _openEmojiPicker(BuildContext context) {
    EmojiPickerSheet.show(
      context,
      onEmojiSelected: (emoji) {
        final text = widget.controller.text;
        final selection = widget.controller.selection;
        final start = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
        final end = selection.extentOffset >= 0 ? selection.extentOffset : text.length;
        final newText = text.replaceRange(
          start < end ? start : end,
          start < end ? end : start,
          emoji,
        );
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (start < end ? start : end) + emoji.length),
        );
      },
      onBackspace: () {
        final text = widget.controller.text;
        if (text.isEmpty) return;
        final selection = widget.controller.selection;
        final start = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
        final end = selection.extentOffset >= 0 ? selection.extentOffset : text.length;
        if (start != end) {
          widget.controller.value = TextEditingValue(
            text: text.replaceRange(start, end, ''),
            selection: TextSelection.collapsed(offset: start),
          );
        } else if (start > 0) {
          final newText = text.substring(0, start - 1) + text.substring(start);
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start - 1),
          );
        }
      },
    );
  }
}

class _TelegramAttachmentSheet extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback? onPickCamera;
  final ValueChanged<Map<String, dynamic>>? onSendPoll;
  final VoidCallback? onSendGift;
  final ValueChanged<CommunityShareItem>? onShareCommunity;
  final ValueChanged<LocationShareData>? onShareLocation;

  const _TelegramAttachmentSheet({
    required this.onPickImage,
    this.onPickCamera,
    this.onSendPoll,
    this.onSendGift,
    this.onShareCommunity,
    this.onShareLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final actions = [
      _AttachmentAction('Camera', Icons.camera_alt_rounded, const Color(0xFF34C759), () {
        if (onPickCamera != null) {
          onPickCamera!();
        } else {
          onPickImage();
        }
      }),
      _AttachmentAction('Gallery', Icons.photo_library_rounded, const Color(0xFF007AFF), onPickImage),
      _AttachmentAction('Poll', Icons.poll_rounded, const Color(0xFFFF9500), () {
        navigator.pop();
        if (onSendPoll != null) {
          CreatePollSheet.show(context, onSubmit: onSendPoll!);
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Poll feature is available here.')),
          );
        }
      }),
      _AttachmentAction('Community', Icons.groups_rounded, const Color(0xFF34C759), () {
        navigator.pop();
        if (onShareCommunity != null) {
          ShareCommunitySheet.show(context, onSelect: onShareCommunity!);
        }
      }),
      _AttachmentAction('Gift', Icons.card_giftcard_rounded, const Color(0xFFFF2D55), () {
        navigator.pop();
        if (onSendGift != null) {
          onSendGift!();
        }
      }),
      _AttachmentAction('Wallet', Icons.account_balance_wallet_rounded, const Color(0xFF5856D6), () {
        navigator.pop();
        WalletSheet.show(context);
      }),
      _AttachmentAction('Location', Icons.location_on_rounded, const Color(0xFFFFCC00), () {
        navigator.pop();
        if (onShareLocation != null) {
          ShareLocationSheet.show(context, onShare: onShareLocation!);
        }
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
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
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
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ],
      ),
    );
  }
}

class _AudioRecordingWaveform extends StatelessWidget {
  final AnimationController animation;
  final bool isDark;

  const _AudioRecordingWaveform({
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final val = animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(12, (index) {
            final offset = index * 0.35;
            final dynamicHeight = (6.0 + 16.0 * (sin(val * 2 * pi + offset).abs())).clamp(4.0, 22.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.8,
              height: dynamicHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.7 + 0.3 * (dynamicHeight / 22.0)),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

