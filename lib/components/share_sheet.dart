import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/design_tokens.dart';

/// Comprehensive Share Service bringing up native phone share sheet + direct app channels.
class AppShare {
  /// Opens the device's native app picker dialog (WhatsApp, TikTok, Instagram, Mail, etc.)
  static Future<void> share(
    BuildContext context, {
    required String text,
    String? subject,
    String? title,
  }) async {
    try {
      await Share.share(
        text,
        subject: subject ?? title ?? 'Murih Space',
      );
    } catch (_) {
      // Fallback if platform share sheet fails
      showShareSheet(context, title: title ?? 'Share', text: text);
    }
  }

  /// Opens a modern social sharing bottom sheet with direct shortcuts to common apps (WhatsApp, TikTok, etc.)
  static void showShareSheet(
    BuildContext context, {
    required String title,
    required String text,
    String? url,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SocialShareModal(title: title, text: text, url: url),
    );
  }
}

class _SocialShareModal extends StatelessWidget {
  final String title;
  final String text;
  final String? url;

  const _SocialShareModal({
    required this.title,
    required this.text,
    this.url,
  });

  String get _sharePayload => url != null ? '$text\n$url' : text;

  Future<void> _launchExternal(BuildContext context, Uri uri, String appName) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $appName. Opening system share…')),
          );
          Share.share(_sharePayload, subject: title);
        }
      }
    } catch (_) {
      if (context.mounted) {
        Share.share(_sharePayload, subject: title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E222A) : Colors.white;

    final shareChannels = [
      _ShareChannel(
        name: 'WhatsApp',
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF25D366),
        onTap: () {
          Navigator.pop(context);
          final encoded = Uri.encodeComponent(_sharePayload);
          _launchExternal(context, Uri.parse('whatsapp://send?text=$encoded'), 'WhatsApp');
        },
      ),
      _ShareChannel(
        name: 'TikTok',
        icon: Icons.music_note_rounded,
        color: const Color(0xFF000000),
        onTap: () {
          Navigator.pop(context);
          // Copy to clipboard and open TikTok
          Clipboard.setData(ClipboardData(text: _sharePayload));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied! Opening TikTok…')),
          );
          _launchExternal(context, Uri.parse('snssdk1233://'), 'TikTok');
        },
      ),
      _ShareChannel(
        name: 'X (Twitter)',
        icon: Icons.tag_rounded,
        color: const Color(0xFF1DA1F2),
        onTap: () {
          Navigator.pop(context);
          final encoded = Uri.encodeComponent(_sharePayload);
          _launchExternal(context, Uri.parse('https://twitter.com/intent/tweet?text=$encoded'), 'X');
        },
      ),
      _ShareChannel(
        name: 'Telegram',
        icon: Icons.send_rounded,
        color: const Color(0xFF0088CC),
        onTap: () {
          Navigator.pop(context);
          final encoded = Uri.encodeComponent(_sharePayload);
          _launchExternal(context, Uri.parse('tg://msg?text=$encoded'), 'Telegram');
        },
      ),
      _ShareChannel(
        name: 'Email',
        icon: Icons.email_rounded,
        color: const Color(0xFFEA4335),
        onTap: () {
          Navigator.pop(context);
          final subj = Uri.encodeComponent(title);
          final body = Uri.encodeComponent(_sharePayload);
          _launchExternal(context, Uri.parse('mailto:?subject=$subj&body=$body'), 'Email');
        },
      ),
      _ShareChannel(
        name: 'Messages / SMS',
        icon: Icons.sms_rounded,
        color: const Color(0xFF34C759),
        onTap: () {
          Navigator.pop(context);
          final body = Uri.encodeComponent(_sharePayload);
          _launchExternal(context, Uri.parse('sms:?body=$body'), 'Messages');
        },
      ),
      _ShareChannel(
        name: 'Copy Link',
        icon: Icons.link_rounded,
        color: const Color(0xFF6B7280),
        onTap: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: url ?? _sharePayload));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied to clipboard!')),
          );
        },
      ),
      _ShareChannel(
        name: 'More Apps…',
        icon: Icons.more_horiz_rounded,
        color: DesignTokens.primary,
        onTap: () {
          Navigator.pop(context);
          Share.share(_sharePayload, subject: title);
        },
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: shareChannels.length,
              itemBuilder: (context, index) {
                final channel = shareChannels[index];
                return InkWell(
                  onTap: channel.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: channel.color.withOpacity(0.12),
                        child: Icon(channel.icon, color: channel.color, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        channel.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

class _ShareChannel {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareChannel({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
