import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';
import '../providers/follow_provider.dart';
import '../utils/format.dart';

/// One post card with author header, announcement badge, poll widget, content, media and engagement actions.
class PostCard extends ConsumerWidget {
  final Post post;
  final int myId;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final PostsSource? source;

  const PostCard({
    super.key,
    required this.post,
    required this.myId,
    this.onCommentTap,
    this.onLike,
    this.onSave,
    this.onShare,
    this.onReport,
    this.source,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = post.author;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
          // Announcement Banner if applicable
          if (post.isAnnouncement) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF3B30)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Official Community Notice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],

          _Header(post: post, author: author, onReport: onReport, isDark: isDark),

          if (post.content.isNotEmpty && !post.isPoll) ...[
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

          // Interactive Poll Widget if poll
          if (post.isPoll) ...[
            const SizedBox(height: 8),
            _PollCard(
              post: post,
              isDark: isDark,
              onVote: (index) {
                final targetSource = source ?? (post.communityId != null
                    ? PostsSource.community(post.communityId!)
                    : const PostsSource.feed('home'));
                ref.read(postsProvider(targetSource).notifier).votePoll(post, index);
              },
            ),
          ],

          if (post.hasMedia) ...[
            const SizedBox(height: 10),
            _MediaGrid(urls: post.mediaUrls),
          ],

          // Location Tag & Hashtags
          if ((post.location != null && post.location!.isNotEmpty) || post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (post.location != null && post.location!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 4),
                        Text(
                          post.location!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final tag in post.hashtags)
                  Text(
                    tag.startsWith('#') ? tag : '#$tag',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
              ],
            ),
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

/// Interactive Poll Card with progress bars and instant voting
class _PollCard extends StatelessWidget {
  final Post post;
  final bool isDark;
  final ValueChanged<int> onVote;

  const _PollCard({
    required this.post,
    required this.isDark,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final question = post.pollQuestion ?? post.content;
    final options = post.pollOptions;
    final results = post.pollResults;
    final userVote = post.userPollVote;
    final hasVoted = userVote != null;
    final totalVotes = results?.totalVotes ?? 0;
    final isExpired = results?.isExpired ?? (post.pollEndsAt != null && post.pollEndsAt!.isBefore(DateTime.now()));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252528) : const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.poll_rounded, size: 16, color: Color(0xFF007AFF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Options
          for (var i = 0; i < options.length; i++) ...[
            _buildPollOption(
              context: context,
              index: i,
              label: options[i],
              results: results,
              isSelected: userVote == i,
              showResults: hasVoted || isExpired,
              isExpired: isExpired,
            ),
            if (i < options.length - 1) const SizedBox(height: 8),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$totalVotes ${totalVotes == 1 ? "vote" : "votes"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '•',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                isExpired ? 'Poll ended' : (hasVoted ? 'Vote recorded' : 'Active poll'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? (isDark ? Colors.grey[400] : Colors.grey[600])
                      : const Color(0xFF34C759),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollOption({
    required BuildContext context,
    required int index,
    required String label,
    required PollResults? results,
    required bool isSelected,
    required bool showResults,
    required bool isExpired,
  }) {
    PollOptionResult? optResult;
    if (results != null && index < results.options.length) {
      optResult = results.options[index];
    }
    final percentage = optResult?.percentage ?? 0.0;
    final votesCount = optResult?.votesCount ?? 0;

    return GestureDetector(
      onTap: isExpired ? null : () => onVote(index),
      child: Container(
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D5DB)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Progress fill bar
            if (showResults)
              FractionallySizedBox(
                widthFactor: (percentage / 100).clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF).withValues(alpha: 0.25)
                        : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF007AFF).withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            // Text & percentage
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showResults) ...[
                    Text(
                      '${percentage.toStringAsFixed(0)}% ($votesCount)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF007AFF) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                (post.community?.name?.isNotEmpty == true)
                    ? 'in ${post.community!.name} • ${formatRelativeTime(post.createdAt)}'
                    : 'Public Wall • ${formatRelativeTime(post.createdAt)}',
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
                errorWidget: (context, url, error) => _mediaPlaceholder(),
                placeholder: (context, url) => _mediaPlaceholder(),
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
                      errorWidget: (context, url, error) => _mediaPlaceholder(),
                      placeholder: (context, url) => _mediaPlaceholder(),
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
