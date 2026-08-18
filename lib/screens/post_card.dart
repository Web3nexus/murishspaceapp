import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/follow_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.rLg),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(post: post, author: author, onReport: onReport, isDark: isDark),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
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
                Icon(Icons.push_pin, size: 13, color: DesignTokens.primary),
                SizedBox(width: 4),
                Text(
                  'Pinned post',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
          _ActionRow(
            post: post,
            onCommentTap: onCommentTap,
            onLike: onLike,
            onSave: onSave,
            onShare: onShare,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final Post post;
  final dynamic author;
  final VoidCallback? onReport;
  final bool isDark;

  const _Header({
    required this.post,
    required this.author,
    this.onReport,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);

    final name = author?.name ?? 'Anonymous';
    final photo = author?.avatarUrl;
    final authorId = author?.id ?? 0;
    final isFollowing = followState.isFollowing(authorId);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
          backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo == null || photo.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF007AFF)),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (authorId > 0 && authorId != 1) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        followNotifier.toggleFollow(authorId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isFollowing ? 'Unfollowed $name' : 'Following $name!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        isFollowing ? '· Following' : '· Follow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isFollowing ? Colors.grey : const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                post.community?.name != null ? '${post.community!.name} · ${formatRelativeTime(post.createdAt)}' : formatRelativeTime(post.createdAt),
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
        if (onReport != null)
          IconButton(
            onPressed: onReport,
            icon: Icon(
              Icons.more_horiz,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
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
            ? CachedNetworkImage(
                imageUrl: urls[0],
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _mediaPlaceholder(),
                placeholder: (_, __) => _mediaPlaceholder(),
              )
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final url in urls)
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _mediaPlaceholder(),
                      placeholder: (_, __) => _mediaPlaceholder(),
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
  final bool isDark;

  const _ActionRow({
    required this.post,
    this.onCommentTap,
    this.onLike,
    this.onSave,
    this.onShare,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _ActionButton(
            icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
            color: post.likedByMe ? DesignTokens.danger : defaultColor,
            label: _count(post.likesCount),
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            color: defaultColor,
            label: _count(post.commentsCount),
            onTap: onCommentTap,
          ),
          const Spacer(),
          _ActionButton(
            icon: post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
            color: post.savedByMe ? DesignTokens.primary : defaultColor,
            label: _count(post.savesCount),
            onTap: onSave,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            color: defaultColor,
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
