import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../utils/format.dart';

/// One post card with author header, content, media and engagement actions.
class PostCard extends StatelessWidget {
  final Post post;
  final int myId;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onReport;

  const PostCard({
    super.key,
    required this.post,
    required this.myId,
    this.onCommentTap,
    this.onLike,
    this.onSave,
    this.onShare,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(post: post, author: author, onReport: onReport),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.content,
              style: const TextStyle(fontSize: 15, height: 1.4, color: DesignTokens.textPrimary),
            ),
          ],
          if (post.hasMedia) ...[
            const SizedBox(height: 10),
            _MediaGrid(urls: post.mediaUrls),
          ],
          if (post.isPinned) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.push_pin, size: 13, color: DesignTokens.primaryDark),
                SizedBox(width: 4),
                Text(
                  'Pinned post',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.primaryDark),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          _ActionRow(
            post: post,
            onCommentTap: onCommentTap,
            onLike: onLike,
            onSave: onSave,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Post post;
  final dynamic author;
  final VoidCallback? onReport;

  const _Header({required this.post, required this.author, this.onReport});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = author?.avatarUrl;
    final name = author?.name ?? 'MurihSpace user';
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: DesignTokens.primarySoft,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: DesignTokens.textPrimary),
              ),
              Text(
                post.community?.name != null ? '${post.community!.name} · ${formatRelativeTime(post.createdAt)}' : formatRelativeTime(post.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
              ),
            ],
          ),
        ),
        if (onReport != null)
          IconButton(
            onPressed: onReport,
            icon: const Icon(Icons.more_horiz, size: 20, color: DesignTokens.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<String> urls;

  const _MediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    final urls = this.urls.take(4).toList();
    final height = urls.length == 1 ? 200.0 : (urls.length == 2 ? 140.0 : 110.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: urls.length == 1
            ? Image.network(
                urls[0],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mediaPlaceholder(),
              )
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final url in urls)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _mediaPlaceholder(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _mediaPlaceholder() {
    return Container(
      color: const Color(0xFFF2F5F8),
      child: const Icon(Icons.broken_image_outlined, color: DesignTokens.textSecondary),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Post post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const _ActionRow({
    required this.post,
    this.onCommentTap,
    this.onLike,
    this.onSave,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _ActionButton(
            icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
            color: post.likedByMe ? DesignTokens.danger : DesignTokens.textSecondary,
            label: _count(post.likesCount),
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            color: DesignTokens.textSecondary,
            label: _count(post.commentsCount),
            onTap: onCommentTap,
          ),
          const Spacer(),
          _ActionButton(
            icon: post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
            color: post.savedByMe ? DesignTokens.primaryDark : DesignTokens.textSecondary,
            label: _count(post.savesCount),
            onTap: onSave,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            color: DesignTokens.textSecondary,
            label: _count(post.sharesCount),
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  String _count(int n) => n > 999 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}
