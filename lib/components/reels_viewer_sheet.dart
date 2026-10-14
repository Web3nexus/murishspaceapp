import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/design_tokens.dart';

/// Fullscreen Short Video / Reels Player Sheet matching MurihSpace design reference.
class ReelsViewerSheet extends StatefulWidget {
  final String authorName;
  final String? authorAvatar;
  final String caption;
  final String location;
  final String videoThumbnail;
  final String likesCount;
  final String commentsCount;
  final String sharesCount;

  const ReelsViewerSheet({
    super.key,
    this.authorName = 'Amina Bello',
    this.authorAvatar,
    this.caption =
        'Unforgettable night at the Sunset Party! 🌅 Music, friends and good vibes only! 💙',
    this.location = 'Calpe, Spain',
    this.videoThumbnail =
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=900&auto=format&fit=crop&q=80',
    this.likesCount = '12.4K',
    this.commentsCount = '320',
    this.sharesCount = '148',
  });

  static void show(
    BuildContext context, {
    String authorName = 'Amina Bello',
    String? authorAvatar,
    String caption =
        'Unforgettable night at the Sunset Party! 🌅 Music, friends and good vibes only! 💙',
    String location = 'Calpe, Spain',
    String videoThumbnail =
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=900&auto=format&fit=crop&q=80',
    String likesCount = '12.4K',
    String commentsCount = '320',
    String sharesCount = '148',
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.black,
      builder: (ctx) => ReelsViewerSheet(
        authorName: authorName,
        authorAvatar: authorAvatar,
        caption: caption,
        location: location,
        videoThumbnail: videoThumbnail,
        likesCount: likesCount,
        commentsCount: commentsCount,
        sharesCount: sharesCount,
      ),
    );
  }

  @override
  State<ReelsViewerSheet> createState() => _ReelsViewerSheetState();
}

class _ReelsViewerSheetState extends State<ReelsViewerSheet> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    final commentController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video / Thumbnail Background
          CachedNetworkImage(
            imageUrl: widget.videoThumbnail,
            fit: BoxFit.cover,
            placeholder: (ctx, url) =>
                Container(color: const Color(0xFF161B26)),
            errorWidget: (ctx, url, err) => Container(
              color: const Color(0xFF161B26),
              child: const Center(
                child: Icon(
                  Icons.videocam_rounded,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),

          // Gradient overlay for legibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.85],
              ),
            ),
          ),

          // 2. Top Header (Back, For You / Following Tabs, Search)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'For You',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Following',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Right Action Column (Avatar +, Like, Comment, Share, Save, Music)
          Positioned(
            right: 14,
            bottom: 90,
            child: Column(
              children: [
                // Avatar with follow badge
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              widget.authorAvatar ??
                              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (!_isFollowing)
                      Positioned(
                        bottom: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _isFollowing = true),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: DesignTokens.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Like
                _reelActionButton(
                  icon: _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isLiked ? const Color(0xFFDC2626) : Colors.white,
                  label: widget.likesCount,
                  onTap: () => setState(() => _isLiked = !_isLiked),
                ),
                const SizedBox(height: 16),

                // Comment
                _reelActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  label: widget.commentsCount,
                  onTap: () {},
                ),
                const SizedBox(height: 16),

                // Share
                _reelActionButton(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  label: widget.sharesCount,
                  onTap: () {},
                ),
                const SizedBox(height: 16),

                // Bookmark / Save
                _reelActionButton(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _isSaved ? DesignTokens.primary : Colors.white,
                  label: 'Save',
                  onTap: () => setState(() => _isSaved = !_isSaved),
                ),
              ],
            ),
          ),

          // 4. Bottom Info & Comment Field
          Positioned(
            left: 16,
            right: 80,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Author row
                Row(
                  children: [
                    Text(
                      widget.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: DesignTokens.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _isFollowing = !_isFollowing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isFollowing
                              ? Colors.white24
                              : DesignTokens.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Caption
                Text(
                  widget.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Location badge
                if (widget.location.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Comment bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            filled: false,
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const Text(
                        '@',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reelActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
