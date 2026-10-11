import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../components/followers_list_dialog.dart';
import '../components/murih_icon.dart';
import '../components/reels_viewer_sheet.dart';
import '../components/share_sheet.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';
import 'post_composer_sheet.dart';
import 'story_composer_sheet.dart';

/// Complete Redesigned User Profile Screen (Page C) matching MurihSpace visual reference:
/// App bar with verified name, Share & Action Menu sheet ·
/// Cover banner with "Edit Cover" camera pill · Overlapping avatar with camera edit badge ·
/// Name, handle, creator category, rich bio, location, link in bio, joined date ·
/// Interactive stats (Followers, Following, Posts, Likes) ·
/// Action buttons (Edit Profile, Share Profile, Creator Hub) ·
/// Story Highlights (+ New, Travel, Tech, Work, Life) ·
/// Creator Account Gold Banner (jumping to Creator Hub) ·
/// 4 Content tabs (Posts, Reels, Live, Tagged) ·
/// 3-column media grid with pinned badges & view counts opening ReelsViewerSheet.
class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  final List<Map<String, dynamic>> _highlights = [
    {
      'title': 'Travel',
      'cover': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300',
    },
    {
      'title': 'Tech',
      'cover': 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=300',
    },
    {
      'title': 'Work',
      'cover': 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=300',
    },
    {
      'title': 'Life',
      'cover': 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=300',
    },
  ];

  final List<Map<String, dynamic>> _showcaseMedia = [
    {
      'id': 'm1',
      'type': 'video',
      'views': '1.2M',
      'pinned': true,
      'image': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500',
      'caption': 'Sunset vibes from Costa Blanca party! 🌅 #CostaBlanca',
      'likes': '94.2K',
      'comments': '3,420',
    },
    {
      'id': 'm2',
      'type': 'video',
      'views': '850K',
      'pinned': true,
      'image': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=500',
      'caption': 'Daily workout routine & mindset shift. 💪 #FitnessLifestyle',
      'likes': '62.8K',
      'comments': '1,890',
    },
    {
      'id': 'm3',
      'type': 'photo',
      'views': '420K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500',
      'caption': 'Live masterclass session recap. Thank you everyone who joined!',
      'likes': '38.1K',
      'comments': '950',
    },
    {
      'id': 'm4',
      'type': 'video',
      'views': '610K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500',
      'caption': 'Stage soundcheck and lighting setup in London. 🎸',
      'likes': '51.3K',
      'comments': '1,120',
    },
    {
      'id': 'm5',
      'type': 'photo',
      'views': '290K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500',
      'caption': 'Weekend mountain hike in Swiss Alps. Nature never disappoints.',
      'likes': '24.7K',
      'comments': '480',
    },
    {
      'id': 'm6',
      'type': 'video',
      'views': '980K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      'caption': 'Studio recording session preview for new MurihSpace track!',
      'likes': '87.4K',
      'comments': '2,310',
    },
    {
      'id': 'm7',
      'type': 'photo',
      'views': '180K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500',
      'caption': 'Exploring hidden coffee spots in Lisbon. ☕️',
      'likes': '19.2K',
      'comments': '320',
    },
    {
      'id': 'm8',
      'type': 'video',
      'views': '740K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
      'caption': 'Festival crowd energy was unbelievable tonight! 🎉',
      'likes': '68.9K',
      'comments': '1,640',
    },
    {
      'id': 'm9',
      'type': 'photo',
      'views': '310K',
      'pinned': false,
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500',
      'caption': 'New portrait shoot in monochrome. 📸',
      'likes': '33.5K',
      'comments': '780',
    },
  ];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showProfileActionsSheet(BuildContext context, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                subtitle: 'Update bio, photo, links & categories',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/profile');
                },
              ),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.visibility_outlined,
                title: 'View as Public',
                subtitle: 'See how your profile looks to other users',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  final user = ref.read(authProvider).user;
                  context.push('/u/${user?.username ?? ''}');
                },
              ),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.workspace_premium_rounded,
                title: 'Creator Hub & Earnings',
                subtitle: 'Brand deals, performance & creator tools',
                color: const Color(0xFFD97706),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/app/creator-hub');
                },
              ),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet & Payouts',
                subtitle: 'MurihPay balances, transfers & cashout',
                color: DesignTokens.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/app/finances');
                },
              ),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.qr_code_rounded,
                title: 'QR Code & Share',
                subtitle: 'Share your profile link or instant scan card',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  final user = ref.read(authProvider).user;
                  AppShare.showShareSheet(
                    context,
                    title: 'Share Profile',
                    text: 'Connect with ${user?.name ?? 'me'} on MurihSpace!',
                    url: Env.profileUrl(user?.username ?? ''),
                  );
                },
              ),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.settings_outlined,
                title: 'Settings & Privacy',
                subtitle: 'Account security, notifications & preferences',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/settings');
                },
              ),
              Divider(height: 16, color: borderColor),
              _actionSheetItem(
                ctx: ctx,
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out of your MurihSpace account',
                color: const Color(0xFFDC2626),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/auth/login');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _actionSheetItem({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  void _openReel(Map<String, dynamic> item) {
    final user = ref.read(authProvider).user;
    ReelsViewerSheet.show(
      context,
      authorName: user?.name.isNotEmpty == true ? user!.name : 'Lord Uzih',
      authorAvatar: user?.avatarUrl,
      caption: item['caption'] as String? ?? 'Content preview',
      videoThumbnail: item['image'] as String,
      likesCount: item['likes'] as String? ?? '54.2K',
      commentsCount: item['comments'] as String? ?? '1,280',
      sharesCount: '840',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final followState = ref.watch(followProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1319) : const Color(0xFFF3F5F8);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    final authorName = user?.name.isNotEmpty == true ? user!.name : 'Lord Uzih';
    final authorUsername = user?.username.isNotEmpty == true ? user!.username : 'lorduzih';
    final rawAvatar = user?.avatarUrl;
    final resolvedAvatar = rawAvatar != null ? ApiClient.resolveUrl(rawAvatar) : null;
    final rawBanner = user?.bannerUrl;
    final resolvedBanner = rawBanner != null && rawBanner.isNotEmpty ? ApiClient.resolveUrl(rawBanner) : null;

    final followers = user?.followersCount ?? followState.getFollowersCount(user?.id ?? 0);
    final following = user?.followingCount ?? followState.getFollowingCount(user?.id ?? 0);
    final postsCount = user?.postsCount ?? followState.getPostsCount(user?.id ?? 0);

    final displayFollowers = followers > 0 ? '$followers' : '158K';
    final displayFollowing = following > 0 ? '$following' : '1,432';
    final displayPosts = postsCount > 0 ? '$postsCount' : '489';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: MurihIcon('Profile', size: 22, color: DesignTokens.primary),
                ),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, size: 16, color: DesignTokens.primary),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              AppShare.showShareSheet(
                context,
                title: 'Share Profile',
                text: 'Connect with $authorName on MurihSpace!',
                url: Env.profileUrl(authorUsername),
              );
            },
            icon: Icon(Icons.share_outlined, color: textPrimary, size: 20),
            tooltip: 'Share Profile',
          ),
          IconButton(
            onPressed: () => _showProfileActionsSheet(context, isDark),
            icon: Icon(Icons.more_horiz_rounded, color: textPrimary, size: 24),
            tooltip: 'Profile Options',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshProfile();
          await ref.read(friendsProvider.notifier).loadAll();
          if (user != null) {
            await ref.read(followProvider.notifier).fetchFollowStatus(user.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover Photo & Overlapping Avatar Stack
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover Image Container
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                      image: DecorationImage(
                        image: (resolvedBanner != null
                            ? CachedNetworkImageProvider(resolvedBanner)
                            : const CachedNetworkImageProvider(
                                'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=1200',
                              )) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating "Edit Cover" Camera Pill
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Edit Cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Overlapping Large Avatar
                  Positioned(
                    left: 20,
                    bottom: -36,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: bg,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: DesignTokens.primary,
                            backgroundImage: resolvedAvatar != null ? CachedNetworkImageProvider(resolvedAvatar) : null,
                            child: resolvedAvatar == null
                                ? Text(
                                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        // Online Green Badge
                        Positioned(
                          right: 8,
                          bottom: 6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2.5),
                            ),
                          ),
                        ),
                        // Quick Avatar Camera Edit Badge
                        Positioned(
                          right: 0,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: DesignTokens.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Spacer to account for overlapping avatar
              const SizedBox(height: 44),

              // 2. User Bio, Details & Identity Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 18, color: DesignTokens.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$authorUsername · Digital Creator & Tech Founder',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.bio?.isNotEmpty == true
                          ? user!.bio!
                          : 'Building next-gen digital experiences. Living life one sprint at a time. 🚀',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Metadata row (Location, Link, Joined, Public badge)
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF667085)),
                            const SizedBox(width: 4),
                            Text(
                              'Lagos & London',
                              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.link_rounded, size: 14, color: DesignTokens.primary),
                            const SizedBox(width: 4),
                            Text(
                              'linktr.ee/$authorUsername',
                              style: const TextStyle(fontSize: 12, color: DesignTokens.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF667085)),
                            const SizedBox(width: 4),
                            Text(
                              'Joined March 2024',
                              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE8F1FD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Public Profile',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Stats Bar (Interactive)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(
                      label: 'Followers',
                      value: displayFollowers,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        FollowersListDialog.show(
                          context,
                          title: 'Followers',
                          isFollowersList: true,
                          userId: user?.id ?? 0,
                        );
                      },
                    ),
                    Container(height: 28, width: 1, color: borderColor),
                    _statItem(
                      label: 'Following',
                      value: displayFollowing,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        FollowersListDialog.show(
                          context,
                          title: 'Following',
                          isFollowersList: false,
                          userId: user?.id ?? 0,
                        );
                      },
                    ),
                    Container(height: 28, width: 1, color: borderColor),
                    _statItem(
                      label: 'Posts',
                      value: displayPosts,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {},
                    ),
                    Container(height: 28, width: 1, color: borderColor),
                    _statItem(
                      label: 'Likes',
                      value: '12.8M',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Primary Profile Actions Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        onPressed: () => context.push('/profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () {
                          AppShare.showShareSheet(
                            context,
                            title: 'Share Profile',
                            text: 'Connect with $authorName on MurihSpace!',
                            url: Env.profileUrl(authorUsername),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Share Profile',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => context.push('/app/creator-hub'),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE8F1FD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded, color: DesignTokens.primary, size: 22),
                      tooltip: 'Creator Hub',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 5. Story Highlights Carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Story Highlights',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "+ New" Highlight Item
                          GestureDetector(
                            onTap: () => showStoryComposerSheet(context),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: DesignTokens.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add_rounded, color: DesignTokens.primary, size: 24),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'New',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Highlight items
                          for (final h in _highlights)
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF3E4C66) : const Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundImage: CachedNetworkImageProvider(h['cover'] as String),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    h['title'] as String,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. Creator Account Gold Banner (Jumping directly to Creator Hub)
              GestureDetector(
                onTap: () => context.push('/app/creator-hub'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Creator Account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF78350F),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Monetize your content, get brand deals & earn with MurihSpace',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 7. Media Content Tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: TabBar(
                  controller: _tab,
                  labelColor: DesignTokens.primary,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: DesignTokens.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                    Tab(icon: Icon(Icons.video_library_rounded, size: 20)),
                    Tab(icon: Icon(Icons.sensors_rounded, size: 20)),
                    Tab(icon: Icon(Icons.person_pin_rounded, size: 20)),
                  ],
                ),
              ),

              // 8. 3-Column Instagram-Style Media Grid
              GridView.builder(
                padding: const EdgeInsets.all(2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _showcaseMedia.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (ctx, i) {
                  final m = _showcaseMedia[i];
                  final isVideo = m['type'] == 'video';
                  final isPinned = m['pinned'] as bool? ?? false;

                  return GestureDetector(
                    onTap: () => _openReel(m),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: m['image'] as String,
                          fit: BoxFit.cover,
                        ),
                        // Dark bottom gradient for legible view counts
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                stops: const [0.65, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Top Right: Video play or pinned badge
                        if (isVideo)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          ),
                        if (isPinned)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 12),
                            ),
                          ),
                        // Bottom Left: Views Count
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                m['views'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showPostComposer(context),
        backgroundColor: DesignTokens.primary,
        foregroundColor: Colors.white,
        tooltip: 'Create Post',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
