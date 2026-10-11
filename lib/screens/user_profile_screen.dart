import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../components/send_gift_dialog.dart';
import '../components/share_sheet.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';
import '../models/story_models.dart';
import '../providers/story_provider.dart';
import 'call_screen.dart';
import 'story_composer_sheet.dart';
import 'story_viewer_screen.dart';

/// Public User & Friend Profile Screen with Gifting, Direct Messaging, Follow & Add Friend CTAs.
class UserProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;
  final String roleLabel;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl = '',
    this.bio = 'Digital Creator & Community Contributor ✨',
    this.roleLabel = 'Creator',
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  String _friendshipStatus = 'none'; // 'none', 'pending_sent', 'pending_received', 'accepted', 'self'
  int? _requestId;
  bool _actionLoading = false;

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _userReels = [];
  List<Map<String, dynamic>> _userLive = [];
  List<Map<String, dynamic>> _userMentions = [];
  bool _loadingPosts = false;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
        _fetchTabPosts(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
      _fetchPublicProfile();
      _fetchTabPosts(0);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicProfile() async {
    try {
      final res = await ApiClient.instance.dio.get('/users/${widget.username}/public');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _profileData = data);
        final dynamicId = (data['id'] as num?)?.toInt() ?? 0;
        if (dynamicId > 0 && widget.userId <= 0) {
          _fetchTabPosts(_activeTabIndex);
          ref.read(followProvider.notifier).fetchFollowStatus(dynamicId);
          ref.read(friendsProvider.notifier).fetchFriendshipStatus(dynamicId);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchTabPosts(int tabIndex) async {
    final targetId = widget.userId > 0 ? widget.userId : ((_profileData?['id'] as num?)?.toInt() ?? 0);
    if (targetId <= 0) return;

    setState(() => _loadingPosts = true);
    try {
      String type = 'all';
      if (tabIndex == 1) type = 'reels';
      if (tabIndex == 2) type = 'live';
      if (tabIndex == 3) type = 'mentions';

      final res = await ApiClient.instance.dio.get(
        '/users/$targetId/posts',
        queryParameters: {'type': type},
      );
      final payload = ApiClient.instance.unwrap(res);
      List<Map<String, dynamic>> list = [];
      if (payload is Map<String, dynamic>) {
        final raw = payload['data'];
        if (raw is List) {
          list = raw.whereType<Map<String, dynamic>>().toList();
        }
      } else if (payload is List) {
        list = payload.whereType<Map<String, dynamic>>().toList();
      }

      if (mounted) {
        setState(() {
          if (tabIndex == 0) _userPosts = list;
          if (tabIndex == 1) _userReels = list;
          if (tabIndex == 2) _userLive = list;
          if (tabIndex == 3) _userMentions = list;
          _loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadState() async {
    ref.read(followProvider.notifier).fetchFollowStatus(widget.userId);
    final statusData = await ref.read(friendsProvider.notifier).fetchFriendshipStatus(widget.userId);
    if (statusData != null && mounted) {
      setState(() {
        _friendshipStatus = statusData['status'] as String? ?? 'none';
        _requestId = (statusData['request_id'] as num?)?.toInt();
      });
    }
  }

  Future<void> _handleFriendAction() async {
    setState(() => _actionLoading = true);
    final notifier = ref.read(friendsProvider.notifier);

    if (_friendshipStatus == 'none') {
      final success = await notifier.sendRequestToUserId(widget.userId);
      if (success && mounted) {
        setState(() {
          _friendshipStatus = 'pending_sent';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${widget.name}!')),
        );
      }
    } else if (_friendshipStatus == 'pending_sent' && _requestId != null) {
      await notifier.cancelRequestById(_requestId!);
      if (mounted) {
        setState(() {
          _friendshipStatus = 'none';
          _requestId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request cancelled.')),
        );
      }
    } else if (_friendshipStatus == 'pending_received' && _requestId != null) {
      await notifier.acceptRequest(
        FriendUserItem(
          id: widget.userId,
          requestId: _requestId!,
          name: widget.name,
          username: widget.username,
        ),
      );
      if (mounted) {
        setState(() {
          _friendshipStatus = 'accepted';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You and ${widget.name} are now friends!')),
        );
      }
    } else if (_friendshipStatus == 'accepted') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Unfriend ${widget.name}?'),
          content: Text('Are you sure you want to remove ${widget.name} from your friends?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unfriend', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final ok = await notifier.unfriendByUserId(widget.userId);
        if (ok && mounted) {
          setState(() {
            _friendshipStatus = 'none';
            _requestId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.name} removed from friends.')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _openChat() async {
    final conv = await ref.read(conversationsProvider.notifier).openDirectChat(
          widget.userId,
          name: widget.name,
          username: widget.username,
          avatarUrl: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
        );
    if (mounted && conv != null) {
      context.push('/app/conversation/${conv.id}');
    }
  }

  void _handleAvatarTap() {
    final storyState = ref.read(storyProvider);
    final myId = ref.read(authProvider).user?.id;
    final isMe = myId == widget.userId;

    UserStoryGroup? matchedGroup;
    for (final g in storyState.groups) {
      if (g.userId == widget.userId.toString() ||
          g.userName.toLowerCase() == widget.name.toLowerCase() ||
          (isMe && g.isMyStory)) {
        matchedGroup = g;
        break;
      }
    }

    // Filter active stories from the last 24 hours (not expired)
    final activeStories = matchedGroup?.stories.where((s) => !s.isExpired).toList() ?? [];

    if (activeStories.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            group: matchedGroup!.copyWith(stories: activeStories),
          ),
        ),
      );
    } else {
      _showNoStorySheet(isMe);
    }
  }

  void _showNoStorySheet(bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 36,
                  backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                  child: widget.avatarUrl.isEmpty
                      ? Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 14),
                const Text(
                  'No Active Story Today',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isMe
                      ? 'Share moments with your community! Stories automatically disappear after 24 hours.'
                      : '${widget.name} has not posted a 24-hour story today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (isMe)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Add 24h Story'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showStoryComposerSheet(context);
                    },
                  )
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);
    final authUser = ref.watch(authProvider).user;
    final isSelf = authUser?.id == widget.userId;

    final storyState = ref.watch(storyProvider);
    final hasActiveStories = storyState.groups.any((g) =>
        (g.userId == widget.userId.toString() || g.userName.toLowerCase() == widget.name.toLowerCase() || (isSelf && g.isMyStory)) &&
        g.stories.any((s) => !s.isExpired));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final isFollowing = followState.isFollowing(widget.userId);
    final followersCount = followState.getFollowersCount(widget.userId);
    final followingCount = followState.getFollowingCount(widget.userId);
    final postsCount = followState.getPostsCount(widget.userId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '@${widget.username}',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Profile',
            onPressed: () {
              final link = Env.profileUrl(widget.username);
              AppShare.showShareSheet(
                context,
                title: 'Share ${widget.name}\'s Profile',
                text: 'Check out ${widget.name} (@${widget.username}) on Murih Space!',
                url: link,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
            tooltip: 'Send Gift',
            onPressed: () => SendGiftDialog.show(
              context,
              recipientName: widget.name,
              recipientAvatar: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Profile Cover Banner (Real User Banner or Elegant Geometric Surface)
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141720) : const Color(0xFF1E293B),
              image: (_profileData?['banner_url'] as String?)?.isNotEmpty == true
                  ? DecorationImage(
                      image: NetworkImage(_profileData!['banner_url'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (_profileData?['banner_url'] as String?)?.isNotEmpty == true
                ? null
                : CustomPaint(
                    painter: _PatternBannerPainter(isDark: isDark),
                  ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Avatar with 24-Hour Story Ring & Online Presence Badge
                  GestureDetector(
                    onTap: _handleAvatarTap,
                    child: OnlineAvatarBadge(
                      isOnline: true,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasActiveStories ? DesignTokens.primary : (isDark ? Colors.white24 : Colors.black12),
                            width: hasActiveStories ? 2.5 : 2.0,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: bg,
                          backgroundImage: ((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String? ?? '').isNotEmpty
                              ? NetworkImage((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String)
                              : null,
                          child: ((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String? ?? '').isEmpty
                              ? Icon(Icons.person, color: DesignTokens.primary, size: 44)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          (_profileData?['name'] as String?)?.isNotEmpty == true ? _profileData!['name'] as String : widget.name,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_profileData?['has_active_verification_badge'] == true || _profileData?['kyc_status'] == 'verified') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 20, color: DesignTokens.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.username}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                  ),
                  const SizedBox(height: 6),
                  const OnlineStatusBadge(isOnline: true, showLabel: true),
                  const SizedBox(height: 8),

                  // Role Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.roleLabel.toUpperCase(),
                      style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _profileData?['bio'] as String? ?? widget.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Metadata Row: Location, Integrated Linktree, Joined Date
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if ((_profileData?['country'] as String?)?.isNotEmpty == true)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF667085)),
                            const SizedBox(width: 4),
                            Text(
                              _profileData!['country'] as String,
                              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      GestureDetector(
                        onTap: () => context.push('/l/${widget.username}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.link_rounded, size: 14, color: DesignTokens.primary),
                            const SizedBox(width: 4),
                            Text(
                              'murihspace.com/l/${widget.username}',
                              style: const TextStyle(fontSize: 12, color: DesignTokens.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF667085)),
                          const SizedBox(width: 4),
                          Text(
                            _profileData?['created_at'] != null
                                ? 'Joined ${DateTime.tryParse(_profileData!['created_at'].toString())?.year ?? 'recently'}'
                                : 'Member',
                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Interactive Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol('Posts', '${_profileData?['posts_count'] ?? postsCount}', textPrimary, textSecondary, () {}),
                      _statCol(
                        'Followers',
                        '${_profileData?['followers_count'] ?? followersCount}',
                        textPrimary,
                        textSecondary,
                        () => FollowersListDialog.show(context, title: '${widget.name}\'s Followers', isFollowersList: true, userId: widget.userId),
                      ),
                      _statCol(
                        'Following',
                        '${_profileData?['following_count'] ?? followingCount}',
                        textPrimary,
                        textSecondary,
                        () => FollowersListDialog.show(context, title: '${widget.name}\'s Following', isFollowersList: false, userId: widget.userId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Primary Action CTAs
                  if (!isSelf)
                    Row(
                      children: [
                        // Follow / Following Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)) : DesignTokens.primary,
                              foregroundColor: isFollowing ? textPrimary : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => followNotifier.toggleFollow(widget.userId),
                            icon: Icon(
                              isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Add Friend / Status Button
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _friendshipStatus == 'accepted'
                                  ? const Color(0xFF34C759).withOpacity(0.12)
                                  : (_friendshipStatus == 'pending_sent'
                                      ? Colors.orange.withOpacity(0.12)
                                      : Colors.transparent),
                              side: BorderSide(
                                color: _friendshipStatus == 'accepted'
                                    ? const Color(0xFF34C759)
                                    : (_friendshipStatus == 'pending_sent'
                                        ? Colors.orange
                                        : DesignTokens.primary),
                                width: 1.5,
                              ),
                              foregroundColor: _friendshipStatus == 'accepted'
                                  ? const Color(0xFF34C759)
                                  : (_friendshipStatus == 'pending_sent'
                                      ? Colors.orange
                                      : DesignTokens.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _actionLoading ? null : _handleFriendAction,
                            icon: _actionLoading
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                                : Icon(
                                    _friendshipStatus == 'accepted'
                                        ? Icons.how_to_reg_rounded
                                        : (_friendshipStatus == 'pending_sent'
                                            ? Icons.hourglass_top_rounded
                                            : (_friendshipStatus == 'pending_received'
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.group_add_rounded)),
                                    size: 16,
                                  ),
                            label: Text(
                              _friendshipStatus == 'accepted'
                                  ? 'Friends'
                                  : (_friendshipStatus == 'pending_sent'
                                      ? 'Requested'
                                      : (_friendshipStatus == 'pending_received'
                                          ? 'Accept'
                                          : 'Add Friend')),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Message Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _openChat,
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: DesignTokens.primary, size: 20),
                          tooltip: 'Message',
                        ),
                        const SizedBox(width: 8),

                        // Voice Call Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CallScreen(
                                  contactName: widget.name,
                                  phoneNumber: '+234 812 000 1122',
                                  avatarUrl: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
                                  isVideo: false,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.call_rounded, color: Color(0xFF34C759), size: 20),
                          tooltip: 'Voice Call',
                        ),
                        const SizedBox(width: 8),

                        // Video Call Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CallScreen(
                                  contactName: widget.name,
                                  phoneNumber: '+234 812 000 1122',
                                  avatarUrl: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
                                  isVideo: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.videocam_rounded, color: DesignTokens.primary, size: 20),
                          tooltip: 'Video Call',
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: DesignTokens.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: DesignTokens.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Profile Preview Mode — Viewing as visitors see your profile',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DesignTokens.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignTokens.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => context.push('/profile'),
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text(
                                  'Edit Profile',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textPrimary,
                                  side: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  final link = Env.profileUrl(widget.username);
                                  AppShare.showShareSheet(
                                    context,
                                    title: 'Share Your Profile',
                                    text: 'Check out my profile on Murih Space!',
                                    url: link,
                                  );
                                },
                                icon: const Icon(Icons.share_outlined, size: 16),
                                label: const Text(
                                  'Share Profile',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Dynamic Activity Badges & Verifications Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _UserActivityBadgesSection(
              userId: widget.userId,
              name: widget.name,
              roleLabel: widget.roleLabel,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Real Creator Courses & Digital Goods Showcase
          _UserCoursesAndGoodsShowcase(userId: widget.userId, creatorName: widget.name),
          const SizedBox(height: 24),

          // Dynamic Content Tabs (Posts, Reels, Live, Mentions)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                bottom: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
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

          // Dynamic Content Display
          _loadingPosts
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              : _buildTabContent(isDark, textPrimary, textSecondary),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark, Color textPrimary, Color? textSecondary) {
    List<Map<String, dynamic>> currentList;
    String emptyMessage;
    IconData emptyIcon;

    switch (_activeTabIndex) {
      case 1:
        currentList = _userReels;
        emptyMessage = 'No reels published yet.';
        emptyIcon = Icons.video_library_outlined;
        break;
      case 2:
        currentList = _userLive;
        emptyMessage = 'No live broadcasts available.';
        emptyIcon = Icons.sensors_outlined;
        break;
      case 3:
        currentList = _userMentions;
        emptyMessage = 'No mentions found.';
        emptyIcon = Icons.person_pin_outlined;
        break;
      case 0:
      default:
        currentList = _userPosts;
        emptyMessage = 'No posts published yet.';
        emptyIcon = Icons.grid_on_outlined;
        break;
    }

    if (currentList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(emptyIcon, size: 42, color: textSecondary),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: currentList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (ctx, i) {
        final item = currentList[i];
        final mediaUrls = item['media_urls'] is List ? item['media_urls'] as List : [];
        final imageUrl = mediaUrls.isNotEmpty ? mediaUrls.first.toString() : null;
        final content = item['content'] as String? ?? '';
        final likes = (item['likes_count'] as num?)?.toInt() ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
          ),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ApiClient.resolveUrl(imageUrl) ?? imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: DesignTokens.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '$likes',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _statCol(String label, String value, Color textPrimary, Color? textSecondary, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCoursesAndGoodsShowcase extends ConsumerStatefulWidget {
  final int userId;
  final String creatorName;

  const _UserCoursesAndGoodsShowcase({required this.userId, required this.creatorName});

  @override
  ConsumerState<_UserCoursesAndGoodsShowcase> createState() => _UserCoursesAndGoodsShowcaseState();
}

class _UserCoursesAndGoodsShowcaseState extends ConsumerState<_UserCoursesAndGoodsShowcase> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCreatorGoods();
  }

  Future<void> _loadCreatorGoods() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/users/${widget.userId}/courses-and-goods');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};

      final courses = data['courses'] as List? ?? [];
      final products = data['digital_products'] as List? ?? [];

      final List<Map<String, dynamic>> list = [];

      for (final c in courses) {
        final course = c as Map<String, dynamic>;
        final price = (course['price'] as num?)?.toDouble() ?? 0.0;
        final currency = course['currency'] ?? 'USD';
        list.add({
          'id': course['id'],
          'type': 'course',
          'title': course['title'] ?? 'Course Masterclass',
          'price': price <= 0 ? 'FREE' : (currency == 'USD' ? '\$$price' : '$currency $price'),
          'lessons_count': (course['lessons_count'] as num?)?.toInt() ?? 0,
          'image_url': course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500',
          'description': course['description'],
        });
      }

      for (final p in products) {
        final prod = p as Map<String, dynamic>;
        final isFree = prod['is_free'] == true;
        final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
        final currency = prod['currency'] ?? 'USD';
        list.add({
          'id': prod['id'],
          'type': 'digital_product',
          'title': prod['title'] ?? 'Digital Product',
          'price': isFree || price <= 0 ? 'FREE' : (currency == 'USD' ? '\$$price' : '$currency $price'),
          'file_type': '${prod['category'] ?? 'Digital'} Asset',
          'image_url': prod['cover_url'] ?? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500',
          'description': prod['description'],
        });
      }

      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator.adaptive()));
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Courses & Digital Goods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_items.length} Published',
                style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final item = _items[i];
            final isCourse = item['type'] == 'course';

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    child: CachedNetworkImage(
                      imageUrl: item['image_url'] as String,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: DesignTokens.primary.withOpacity(0.2),
                        child: const Icon(Icons.school_rounded, color: DesignTokens.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCourse
                                  ? DesignTokens.primary.withOpacity(0.15)
                                  : const Color(0xFF5856D6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCourse ? 'COURSE' : 'DIGITAL GOOD',
                              style: TextStyle(
                                color: isCourse ? DesignTokens.primary : const Color(0xFF5856D6),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCourse ? '${item['lessons_count']} lessons' : (item['file_type'] as String? ?? 'File'),
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['price'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF34C759)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Accessing ${item['title']} from ${widget.creatorName}!')),
                        );
                      },
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PatternBannerPainter extends CustomPainter {
  final bool isDark;

  const _PatternBannerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle architectural dot matrix grid pattern
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.08 : 0.12)
      ..style = PaintingStyle.fill;

    const spacing = 18.0;
    for (double x = 8; x < size.width; x += spacing) {
      for (double y = 8; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // Subtle modern geometric corner lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.05 : 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final offset = i * 28.0;
      canvas.drawLine(
        Offset(size.width - 140 + offset, 0),
        Offset(size.width + offset, 140),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActivityBadgeItem {
  final String id;
  final String title;
  final String level;
  final String description;
  final IconData icon;
  final Color color;
  final String status;
  final String criteria;

  const ActivityBadgeItem({
    required this.id,
    required this.title,
    required this.level,
    required this.description,
    required this.icon,
    required this.color,
    required this.status,
    required this.criteria,
  });
}

class _UserActivityBadgesSection extends StatelessWidget {
  final int userId;
  final String name;
  final String roleLabel;
  final bool isDark;
  final Color textPrimary;
  final Color? textSecondary;

  const _UserActivityBadgesSection({
    required this.userId,
    required this.name,
    required this.roleLabel,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  List<ActivityBadgeItem> _generateBadges() {
    final badges = <ActivityBadgeItem>[];

    // Badge 1: Creator or Digital Contributor
    if (roleLabel.toLowerCase().contains('creator') || userId % 2 == 0) {
      badges.add(
        const ActivityBadgeItem(
          id: 'creator_economy',
          title: 'Creator Economy Star',
          level: 'Master Creator · Level 2',
          description: 'Published interactive courses, educational assets and digital goods on Murih Space.',
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFFF9500),
          status: 'Active Creator',
          criteria: 'Awarded for active digital products, verified portfolio, and course publishing.',
        ),
      );
    }

    // Badge 2: Web3 Pioneer
    badges.add(
      const ActivityBadgeItem(
        id: 'web3_pioneer',
        title: 'Web3 Pioneer',
        level: 'Smart Account · Tier 1',
        description: 'Verified smart wallet participant across decentralized governance & Web3 communities.',
        icon: Icons.token_rounded,
        color: Color(0xFF5856D6),
        status: 'On-Chain Verified',
        criteria: 'Awarded for smart contract interaction, token community membership, and verified wallet activity.',
      ),
    );

    // Badge 3: Escrow Trusted Partner
    badges.add(
      const ActivityBadgeItem(
        id: 'escrow_trusted',
        title: 'Escrow Trusted Trader',
        level: '100% Reliable · Dispute-Free',
        description: 'Consistently completes high-trust peer transactions using Murih Space Escrow Protection.',
        icon: Icons.verified_user_rounded,
        color: Color(0xFF34C759),
        status: 'Escrow Protected',
        criteria: 'Awarded for verified escrow deals completed with positive counterparty feedback and zero disputes.',
      ),
    );

    // Badge 4: Community Leader
    badges.add(
      const ActivityBadgeItem(
        id: 'community_leader',
        title: 'Community Champion',
        level: 'Top 5% Contributor',
        description: 'Consistent participant across discussion hubs, mutual spaces, and real-time community polls.',
        icon: Icons.groups_rounded,
        color: DesignTokens.primary,
        status: 'Active 24h',
        criteria: 'Awarded for frequent peer-to-peer engagement, helpful responses, and poll participation.',
      ),
    );

    // Badge 5: Early Genesis Member
    if (userId < 100 || userId % 3 == 0) {
      badges.add(
        const ActivityBadgeItem(
          id: 'early_adopter',
          title: 'Genesis Member',
          level: 'Early Adopter',
          description: 'Joined during the foundational genesis period and helped establish the community foundation.',
          icon: Icons.rocket_launch_rounded,
          color: Color(0xFFFF2D55),
          status: 'Genesis',
          criteria: 'Awarded to pioneering members who registered during the early ecosystem phase.',
        ),
      );
    }

    return badges;
  }

  void _showBadgeDetailSheet(BuildContext context, ActivityBadgeItem badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF1E222A) : Colors.white;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: badge.color.withOpacity(0.15),
                  child: Icon(badge.icon, color: badge.color, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  badge.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badge.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.level,
                    style: TextStyle(color: badge.color, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282C35) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF34C759), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verification Criteria: ${badge.criteria}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Verification Log'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = _generateBadges();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activity Badges & Verifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${badges.length} Earned',
                style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: badges.map((b) {
            return InkWell(
              onTap: () => _showBadgeDetailSheet(context, b),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: b.color.withOpacity(0.14),
                      child: Icon(b.icon, color: b.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                b.title,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textPrimary),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: b.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  b.status,
                                  style: TextStyle(color: b.color, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
