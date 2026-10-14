import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/story_provider.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import 'post_composer_sheet.dart';
import 'post_report_dialog.dart';
import 'story_composer_sheet.dart';
import 'story_viewer_screen.dart';
import '../components/go_live_setup_dialog.dart';
import '../components/kyc_live_gate_dialog.dart';
import '../components/live_now_rail.dart';
import '../components/murih_icon.dart';
import '../providers/chat_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/live_discovery_provider.dart';

/// FB/Instagram style Home Feed screen with MurihSpace Brand Logo & Messenger jump action.
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenMessages;

  const HomeScreen({super.key, required this.onOpenMessages});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _showQuickCreateMenu(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: DesignTokens.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Something New',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'Choose what you want to share with MurihSpace',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2x2 Action Cards
              Row(
                children: [
                  Expanded(
                    child: _buildQuickCreateCard(
                      ctx: ctx,
                      title: 'Create Post',
                      subtitle: 'Discussion & Polls',
                      icon: Icons.article_rounded,
                      gradient: const [DesignTokens.primary, Color(0xFF5856D6)],
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        showPostComposer(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickCreateCard(
                      ctx: ctx,
                      title: 'Add Story',
                      subtitle: '24h Visual Status',
                      icon: Icons.auto_stories_rounded,
                      gradient: const [Color(0xFFFF9500), Color(0xFFFF2D55)],
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        showStoryComposerSheet(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickCreateCard(
                      ctx: ctx,
                      title: 'Go Live',
                      subtitle: 'Live Video Broadcast',
                      icon: Icons.videocam_rounded,
                      gradient: const [Color(0xFFFF3B30), Color(0xFFFF453A)],
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        final user = ref.read(authProvider).user;
                        final kycStatus = user?.kycStatus.toLowerCase() ?? 'unsubmitted';
                        if (kycStatus != 'verified' && kycStatus != 'approved') {
                          showKycRequiredLiveModal(context);
                        } else {
                          GoLiveSetupDialog.show(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickCreateCard(
                      ctx: ctx,
                      title: 'Community',
                      subtitle: 'Launch New Space',
                      icon: Icons.groups_rounded,
                      gradient: const [Color(0xFFAF52DE), Color(0xFF5856D6)],
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/app/communities');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildQuickCreateCard({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final user = ref.watch(authProvider).user;

    final unreadNotes = ref.watch(notificationsProvider).unread;
    final unreadChats = ref.watch(conversationsProvider).unreadTotal;
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: BrandLogo(
          role: user?.role,
          height: 28,
          isDark: isDark,
        ),
        actions: [
          const _LiveActionButton(),
          // Notifications Bell with Unread Badge
          IconButton(
            onPressed: () => context.push('/profile/notifications'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                MurihIcon(
                  'Notification',
                  size: 22,
                  color: isDark ? Colors.white : const Color(0xFF17202B),
                ),
                if (unreadNotes > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Notifications',
          ),

          // Messages Jump Button (BrandFavicon with unread badge)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: widget.onOpenMessages,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  BrandFavicon(
                    size: 22,
                    isDark: isDark,
                  ),
                  if (unreadChats > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unreadChats',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Messages',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref
                .read(postsProvider(const PostsSource.feed('home')).notifier)
                .refresh(),
            ref.read(liveDiscoveryProvider.notifier).refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Stories Row at Top of Feed (per Instagram/Facebook & reference)
              const _StoriesRow(),
              const SizedBox(height: 6),

              // 2. What's on your mind Composer Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final raw = user?.avatarUrl;
                              final resolved = raw != null ? ApiClient.resolveUrl(raw) : null;
                              return CircleAvatar(
                                radius: 18,
                                backgroundColor: DesignTokens.primary,
                                backgroundImage: resolved != null ? CachedNetworkImageProvider(resolved) : null,
                                child: resolved == null
                                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _compose,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  "What's on your mind?",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showQuickCreateMenu(context, isDark),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: DesignTokens.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, color: DesignTokens.primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _composerPill(
                            iconName: 'Image',
                            label: 'Photo',
                            color: const Color(0xFF16A34A),
                            onTap: _compose,
                            isDark: isDark,
                          ),
                          _composerPill(
                            iconName: 'Video',
                            label: 'Video',
                            color: const Color(0xFFDC2626),
                            onTap: _compose,
                            isDark: isDark,
                          ),
                          _composerPill(
                            iconName: 'Camera',
                            label: 'Live',
                            color: const Color(0xFF7C3AED),
                            onTap: () => context.push('/live/start'),
                            isDark: isDark,
                          ),
                          _composerPill(
                            iconName: 'Chart',
                            label: 'Poll',
                            color: DesignTokens.primary,
                            onTap: _compose,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. People you may know
              const _PeopleYouMayKnow(),
              const SizedBox(height: 6),

              // 4. Live Now rail
              const LiveNowRail(),

              // 5. Home Feed Posts
              const _HomeFeedPosts(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _compose() async {
    final post = await showPostComposer(context);
    if (post != null) {
      ref.read(postsProvider(const PostsSource.feed('home')).notifier).prepend(post);
    }
  }

  Widget _composerPill({
    required String iconName,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MurihIcon(iconName, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesRow extends ConsumerWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storyState = ref.watch(storyProvider);
    final user = ref.watch(authProvider).user;
    final groups = storyState.groups;

    return Container(
      height: 105,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        itemBuilder: (ctx, i) {
          final group = groups[i];

          // -----------------------------------------------------------------
          // ITEM 0: "Add Story" / "Your Story" Bubble
          // -----------------------------------------------------------------
          if (group.isMyStory) {
            final hasStories = group.stories.isNotEmpty;
            final rawMyAvatar = user?.avatarUrl ?? user?.avatar ?? group.userAvatar;
            final myAvatar = rawMyAvatar != null ? ApiClient.resolveUrl(rawMyAvatar) : null;
            final hasMyAvatar = myAvatar != null && myAvatar.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () {
                  if (hasStories) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerScreen(group: group),
                      ),
                    );
                  } else {
                    showStoryComposerSheet(context);
                  }
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasStories
                                ? const LinearGradient(
                                    colors: [DesignTokens.primary, Color(0xFF5856D6), Color(0xFFFF2D55)],
                                  )
                                : null,
                            color: hasStories ? null : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6)),
                          ),
                          child: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            backgroundImage: hasMyAvatar ? CachedNetworkImageProvider(myAvatar) : null,
                            child: !hasMyAvatar
                                ? Icon(Icons.person, color: isDark ? Colors.white : Colors.black, size: 20)
                                : null,
                          ),
                        ),
                        // Plus (+) Badge Icon
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => showStoryComposerSheet(context),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: DesignTokens.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF18191A) : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasStories ? 'Your Story' : 'Add Story',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // -----------------------------------------------------------------
          // ITEM > 0: Followed Friends & Joined Communities Story Bubbles
          // -----------------------------------------------------------------
          final hasUnseen = group.hasUnseen;
          final rawAvatar = group.userAvatar;
          final friendAvatar = rawAvatar != null ? ApiClient.resolveUrl(rawAvatar) : null;
          final hasFriendAvatar = friendAvatar != null && friendAvatar.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(group: group),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasUnseen
                          ? const LinearGradient(
                              colors: [DesignTokens.primary, Color(0xFF5856D6), Color(0xFFFF2D55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: hasUnseen
                          ? null
                          : Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              width: 1.5,
                            ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      backgroundImage: hasFriendAvatar ? CachedNetworkImageProvider(friendAvatar) : null,
                      child: !hasFriendAvatar
                          ? Icon(Icons.person, color: isDark ? Colors.white : Colors.black, size: 25)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      group.userName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasUnseen ? FontWeight.bold : FontWeight.w600,
                        color: hasUnseen
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PeopleYouMayKnow extends ConsumerWidget {
  const _PeopleYouMayKnow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(feedSuggestionsProvider);
    final notifier = ref.read(feedSuggestionsProvider.notifier);
    ref.listen(feedSuggestionsProvider.select((s) => s.error), (prev, error) {
      if (error == null) return;
      notifier.clearError();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    });
    final suggestions = state.suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B1F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE4E6EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: DesignTokens.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'People You May Know',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${suggestions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final user = suggestions[i];
                  return _PeopleYouMayKnowCard(
                    user: user,
                    isDark: isDark,
                    onAdd: () => notifier.sendRequest(user),
                    onCancel: () => notifier.cancelRequest(user),
                    onDismiss: () => notifier.dismiss(user.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleYouMayKnowCard extends StatelessWidget {
  final FriendUserItem user;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  const _PeopleYouMayKnowCard({
    required this.user,
    required this.isDark,
    required this.onAdd,
    required this.onCancel,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl != null && user.avatarUrl!.isNotEmpty
        ? user.avatarUrl
        : null;

    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242426) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: () => _openProfile(context),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: DesignTokens.primary,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openProfile(context),
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Text(
                '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (user.mutualCount > 0)
                Text(
                  '${user.mutualCount} mutual',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: DesignTokens.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: user.status == 'accepted'
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _openProfile(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: DesignTokens.primary),
                            const SizedBox(width: 3),
                            const Text(
                              'Friends',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : user.status == 'pending_received'
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.primary,
                              side: const BorderSide(color: DesignTokens.primary, width: 1.2),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => context.push('/friends'),
                            child: const Text(
                              'Respond',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          )
                        : user.status == 'pending_sent'
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.primary,
                              side: const BorderSide(color: DesignTokens.primary, width: 1.2),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: onCancel,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: DesignTokens.primary,
                                ),
                                const SizedBox(width: 3),
                                const Text(
                                  'Requested',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: onAdd,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 3),
                                const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    context.push(
      '/profile/user/${user.id}?name=${Uri.encodeComponent(user.name)}&username=${Uri.encodeComponent(user.username)}',
    );
  }
}

class _HomeFeedPosts extends ConsumerWidget {
  const _HomeFeedPosts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = const PostsSource.feed('home');
    final state = ref.watch(postsProvider(source));
    final myId = ref.watch(authProvider).user?.id ?? 0;
    final notifier = ref.read(postsProvider(source).notifier);

    if (state.loading && state.posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingStateWidget(message: 'Loading feed…'),
      );
    }
    if (state.error != null && state.posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: ErrorStateWidget(
          title: 'Could not load feed',
          description: state.error!,
          onRetry: () => notifier.refresh(),
        ),
      );
    }
    if (state.posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: EmptyStateWidget(
            icon: Icons.explore_outlined,
            title: 'Nothing in feed yet',
            description: 'Follow people and join communities to build your feed.',
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.posts.length,
      itemBuilder: (_, i) {
        final post = state.posts[i];
        return PostCard(
          post: post,
          myId: myId,
          onLike: () => notifier.toggleLike(post, myId: myId),
          onSave: () => notifier.toggleSave(post),
          onCommentTap: () => showPostComments(
            context,
            post: post,
            myId: myId,
            onAddComment: (content) => notifier.addComment(post, content),
          ),
          onShare: () async {
            await notifier.share(post);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post shared.')),
              );
            }
          },
          onReport: () async {
            final reason = await showPostReportDialog(context, post: post);
            if (reason == null) return;
            final ok = await notifier.report(post, reason);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Post reported. Thanks!' : 'Could not report this post.')),
              );
            }
          },
        );
      },
    );
  }
}

/// App bar entry into live discovery. Shows a red dot while broadcasts are on
/// air so the rail and the screen stay reachable even when the feed is quiet.
class _LiveActionButton extends ConsumerWidget {
  const _LiveActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLive = ref.watch(
      liveDiscoveryProvider.select((s) => s.streams.isNotEmpty),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: 'Live Now',
        onPressed: () => context.push('/app/live-now'),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.sensors_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            if (hasLive)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: DesignTokens.danger,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.black : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
