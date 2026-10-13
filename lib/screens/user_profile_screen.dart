import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/format.dart';

import '../components/followers_list_dialog.dart';
import '../components/murih_icon.dart';
import '../components/send_gift_dialog.dart';
import '../components/share_sheet.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/feature_flag_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';
import '../models/story_models.dart';
import '../providers/story_provider.dart';
import 'story_composer_sheet.dart';
import 'story_viewer_screen.dart';

import '../components/ui_states.dart';

/// Public User & Friend Profile Screen with Gifting, Direct Messaging, Follow & Add Friend CTAs.
class UserProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;
  final String roleLabel;
  final bool isPreview;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl = '',
    this.bio = 'Digital Creator & Community Contributor',
    this.roleLabel = 'Creator',
    this.isPreview = false,
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
  List<Map<String, dynamic>> _userStories = [];
  bool _loadingPosts = false;
  int _activeTabIndex = 0;
  String _previewMode = 'public'; // 'public' or 'my_view'

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
      _fetchUserStories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserStories() async {
    final targetId = widget.userId > 0 ? widget.userId : ((_profileData?['id'] as num?)?.toInt() ?? 0);
    if (targetId <= 0) return;
    try {
      final res = await ApiClient.instance.dio.get('/users/$targetId/stories');
      final payload = ApiClient.instance.unwrap(res);
      if (payload is List && mounted) {
        setState(() {
          _userStories = payload.whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (_) {}
  }

  bool _profileNotFound = false;

  Future<void> _fetchPublicProfile() async {
    try {
      final res = await ApiClient.instance.dio.get('/users/${widget.username}/public');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        setState(() {
          _profileData = data;
          _profileNotFound = false;
        });
        final dynamicId = (data['id'] as num?)?.toInt() ?? 0;
        if (dynamicId > 0 && widget.userId <= 0) {
          _fetchTabPosts(_activeTabIndex);
          _fetchUserStories();
          ref.read(followProvider.notifier).fetchFollowStatus(dynamicId);
          ref.read(friendsProvider.notifier).fetchFriendshipStatus(dynamicId);
        }
      }
    } catch (e) {
      if (mounted) {
        final status = e is DioException
            ? e.response?.statusCode
            : (e is ApiException ? e.status : null);
        setState(() => _profileNotFound = status == 404);
      }
    }
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

  void _showActionMenuSheet() {
    final authUser = ref.read(authProvider).user;
    final isSelf = authUser?.id == widget.userId;
    final effectiveIsSelf = widget.isPreview ? (_previewMode == 'my_view') : isSelf;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  effectiveIsSelf ? 'Profile Options' : '@${widget.username}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 8),
                if (effectiveIsSelf) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: DesignTokens.primary),
                    title: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                    subtitle: Text('Change bio, avatar, banner & links', style: TextStyle(fontSize: 12, color: textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/profile');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _previewMode == 'public' ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: DesignTokens.primary,
                    ),
                    title: Text(
                      _previewMode == 'public' ? 'Switch to My View' : 'View as Public Visitor',
                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    subtitle: Text('Preview how your profile appears to others', style: TextStyle(fontSize: 12, color: textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _previewMode = _previewMode == 'public' ? 'my_view' : 'public';
                      });
                    },
                  ),
                  ListTile(
                    leading: const MurihIcon('Video', color: DesignTokens.primary, size: 22),
                    title: Text('Creator Studio', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                    subtitle: Text('Publishing tools, scheduling, growth & analytics', style: TextStyle(fontSize: 12, color: textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/creator-studio');
                    },
                  ),
                  ListTile(
                    leading: const MurihIcon('Work', color: Color(0xFFFF9500), size: 22),
                    title: Text('Brand Studio', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                    subtitle: Text('Brand partnerships, briefs & escrow campaigns', style: TextStyle(fontSize: 12, color: textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final flags = ref.read(featureFlagProvider);
                      final role = ref.read(authProvider).user?.role ?? UserRole.member;
                      if (!flags.isEnabled('brand_deals')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Brand Deals Marketplace is currently disabled.')),
                        );
                        return;
                      }
                      if (role != UserRole.creator && role != UserRole.admin) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Brand Studio is exclusively for Verified Creators.')),
                        );
                        return;
                      }
                      context.push('/brand-studio');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_rounded, color: DesignTokens.primary),
                    title: Text('MurihPay Financial Hub', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                    subtitle: Text('Manage multi-currency balances & ledger', style: TextStyle(fontSize: 12, color: textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/wallet');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: DesignTokens.primary),
                    title: Text('Settings & Privacy', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/settings');
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: DesignTokens.primary),
                  title: Text('Share Profile', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    AppShare.showShareSheet(
                      context,
                      title: 'Share Profile',
                      text: 'Check out @${widget.username} on Murih Space!',
                      url: Env.profileUrl(widget.username),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: DesignTokens.primary),
                  title: Text('Copy Profile Link', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: Env.profileUrl(widget.username)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile link copied to clipboard!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded, color: DesignTokens.primary),
                  title: Text('Profile QR Code', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showQrDialog();
                  },
                ),
                if (!effectiveIsSelf) ...[
                  ListTile(
                    leading: _actionLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                        : Icon(
                            _friendshipStatus == 'accepted'
                                ? Icons.how_to_reg_rounded
                                : (_friendshipStatus == 'pending_sent'
                                    ? Icons.hourglass_top_rounded
                                    : (_friendshipStatus == 'pending_received'
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.group_add_rounded)),
                            color: _friendshipStatus == 'accepted'
                                ? const Color(0xFF34C759)
                                : (_friendshipStatus == 'pending_sent'
                                    ? Colors.orange
                                    : DesignTokens.primary),
                          ),
                    title: Text(
                      _friendshipStatus == 'accepted'
                          ? 'Friends (Tap to Unfriend)'
                          : (_friendshipStatus == 'pending_sent'
                              ? 'Request Sent (Tap to Cancel)'
                              : (_friendshipStatus == 'pending_received'
                                  ? 'Accept Friend Request'
                                  : 'Add as Friend')),
                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleFriendAction();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                    title: const Text('Report Profile', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleReportProfile();
                    },
                  ),
                ] else ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Log Out?'),
                          content: const Text('Are you sure you want to sign out of MurihSpace?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Log Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        ref.read(authProvider.notifier).logout();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleReportProfile() async {
    final targetId = (_profileData?['id'] as num?)?.toInt() ?? widget.userId;
    if (targetId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not report this profile right now.')),
      );
      return;
    }
    try {
      await ApiClient.instance.dio.post('/reports', data: {
        'reported_type': 'user',
        'reported_id': targetId,
        'reason': 'inappropriate',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile reported for review. Thank you.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not report this profile. Please try again.')),
        );
      }
    }
  }

  void _showQrDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              Text(
                'Scan to connect with @${widget.username} on MurihSpace',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 180, color: DesignTokens.primary),
                    const SizedBox(height: 12),
                    Text(
                      widget.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                    Text(
                      '@${widget.username}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: Env.profileUrl(widget.username)));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile URL copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPostDetailModal(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PostDetailSheet(
        postData: item,
        authorName: (_profileData?['name'] as String?)?.isNotEmpty == true ? _profileData!['name'] as String : widget.name,
        authorUsername: widget.username,
        authorAvatar: (_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String? ?? '',
        authorId: widget.userId,
      ),
    );
  }

  Widget _buildStoryHighlights(bool isDark, Color textPrimary, Color? textSecondary, bool isSelf) {
    if (_userStories.isEmpty && !isSelf) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Story Highlights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              if (_userStories.isNotEmpty)
                Text(
                  '${_userStories.length} highlights',
                  style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: (isSelf ? 1 : 0) + _userStories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (ctx, index) {
              if (isSelf && index == 0) {
                return GestureDetector(
                  onTap: () => showStoryComposerSheet(context),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: DesignTokens.primary, width: 2),
                          color: DesignTokens.primary.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.add_rounded, color: DesignTokens.primary, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'New',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ],
                  ),
                );
              }

              final storyIndex = isSelf ? index - 1 : index;
              final story = _userStories[storyIndex];
              final mediaUrl = story['media_url'] as String? ?? '';
              final resolvedUrl = ApiClient.resolveUrl(mediaUrl) ?? mediaUrl;
              final caption = story['caption'] as String? ?? 'Highlight';

              return GestureDetector(
                onTap: () {
                  _handleAvatarTap();
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: DesignTokens.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 29,
                        backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                        backgroundImage: resolvedUrl.isNotEmpty ? NetworkImage(resolvedUrl) : null,
                        child: resolvedUrl.isEmpty
                            ? const Icon(Icons.photo_library_outlined, size: 20, color: DesignTokens.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        caption,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);
    final authUser = ref.watch(authProvider).user;
    final isSelf = authUser?.id == widget.userId;
    final isPreviewMode = widget.isPreview;
    final effectiveIsSelf = isPreviewMode ? (_previewMode == 'my_view') : isSelf;

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
          isPreviewMode ? 'Preview Profile' : '@${widget.username}',
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
          if (!effectiveIsSelf)
            IconButton(
              icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
              tooltip: 'Send Gift',
              onPressed: () => SendGiftDialog.show(
                context,
                recipientName: widget.name,
                recipientAvatar: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'More Options',
            onPressed: _showActionMenuSheet,
          ),
        ],
        bottom: isPreviewMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _previewMode = 'public'),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _previewMode == 'public' ? DesignTokens.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Public View',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _previewMode == 'public' ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _previewMode = 'my_view'),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _previewMode == 'my_view' ? DesignTokens.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'My View',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _previewMode == 'my_view' ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      bottomNavigationBar: isPreviewMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ),
            )
          : null,
      body: _profileNotFound
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: CenteredEmptyStateWidget(
                  icon: Icons.person_off_outlined,
                  title: 'User Profile Not Found',
                  description: 'This profile is not available or does not exist on MurihSpace.',
                  actionLabel: 'Go Back',
                  onAction: () => Navigator.of(context).pop(),
                  minHeight: 320,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
          // 1. Cover Photo & Overlapping Avatar Stack (matching you_screen.dart)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image Container
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                  image: (_profileData?['banner_url'] as String?)?.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(_profileData!['banner_url'] as String),
                          fit: BoxFit.cover,
                        )
                      : const DecorationImage(
                          image: CachedNetworkImageProvider(
                            'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=1200',
                          ),
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

              // Overlapping Large Avatar (LEFT-ALIGNED at left: 20, bottom: -36)
              Positioned(
                left: 20,
                bottom: -36,
                child: GestureDetector(
                  onTap: _handleAvatarTap,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                          border: hasActiveStories
                              ? Border.all(color: DesignTokens.primary, width: 2.5)
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: DesignTokens.primary,
                          backgroundImage: ((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String? ?? '').isNotEmpty
                              ? CachedNetworkImageProvider(
                                  ((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String),
                                )
                              : null,
                          child: ((_profileData?['avatar_url'] ?? _profileData?['avatar'] ?? widget.avatarUrl) as String? ?? '').isEmpty
                              ? Text(
                                  ((_profileData?['name'] as String?)?.isNotEmpty == true
                                          ? (_profileData!['name'] as String)[0].toUpperCase()
                                          : widget.name.isNotEmpty
                                              ? widget.name[0].toUpperCase()
                                              : 'U'),
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
                      if (effectiveIsSelf)
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
              ),
            ],
          ),

          // Spacer to account for overlapping avatar
          const SizedBox(height: 44),

          // 2. User Bio, Details & Identity Card (LEFT-ALIGNED matching you_screen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (_profileData?['name'] as String?)?.isNotEmpty == true ? _profileData!['name'] as String : widget.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (_profileData?['has_active_verification_badge'] == true || _profileData?['kyc_status'] == 'verified') ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 18, color: DesignTokens.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${widget.username} · ${widget.roleLabel}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (_profileData?['bio'] as String?)?.isNotEmpty == true
                      ? _profileData!['bio'] as String
                      : (widget.bio.isNotEmpty ? widget.bio : 'Building next-gen digital experiences on MurihSpace.'),
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
                    if ((_profileData?['country'] as String?)?.isNotEmpty == true || (_profileData?['state'] as String?)?.isNotEmpty == true)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF667085)),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if ((_profileData?['state'] as String?)?.isNotEmpty == true) _profileData!['state'] as String,
                              if ((_profileData?['country'] as String?)?.isNotEmpty == true) _profileData!['country'] as String,
                            ].join(', '),
                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: Env.profileUrl(widget.username)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Profile link copied: ${Env.profileUrl(widget.username)}')),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link_rounded, size: 14, color: DesignTokens.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${Env.profileDomain}/@${widget.username}',
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
                              ? 'Joined ${DateTime.tryParse(_profileData!['created_at'].toString())?.year ?? DateTime.now().year}'
                              : 'Joined ${DateTime.now().year}',
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

          // 3. Stats Bar (Matching you_screen card style)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
            ),
            child: Row(
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
                _statCol('Likes', '${_profileData?['likes_count'] ?? 0}', textPrimary, textSecondary, () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Action Buttons Row:
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: !effectiveIsSelf
                ? Row(
                    children: [
                      // Follow / Following Button (Same size as Message)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)) : DesignTokens.primary,
                            foregroundColor: isFollowing ? textPrimary : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                      // Message Button (Same size as Follow)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _openChat,
                          icon: const MurihIcon('Chat', color: DesignTokens.primary, size: 18),
                          label: const Text(
                            'Message',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3rd Button: View Followers (Icon only from our icon file)
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF2F4F7),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => FollowersListDialog.show(
                          context,
                          title: '${widget.name}\'s Followers',
                          isFollowersList: true,
                          userId: widget.userId,
                        ),
                        icon: MurihIcon('2 User', color: textPrimary, size: 20),
                        tooltip: 'Followers',
                      ),
                    ],
                  )
                : Column(
                    children: [
                      if (widget.isPreview)
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
                          // Expanded Edit Profile Button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignTokens.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => context.push('/profile'),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icon-only Followers Button using same 2 User icon
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF2F4F7),
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.push('/followers'),
                            icon: MurihIcon('2 User', color: textPrimary, size: 20),
                            tooltip: 'Followers',
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Dynamic Activity Badges & Verifications Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _UserActivityBadgesSection(
              userId: widget.userId,
              name: widget.name,
              roleLabel: widget.roleLabel,
              profileData: _profileData,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Real Creator Courses & Digital Goods Showcase
          _UserCoursesAndGoodsShowcase(userId: widget.userId, creatorName: widget.name),
          const SizedBox(height: 20),

          // Dynamic Story Highlights Row (Matching cad95bd7.jpg & dc41ec71.jpg)
          _buildStoryHighlights(isDark, textPrimary, textSecondary, effectiveIsSelf),
          const SizedBox(height: 16),

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
    IconData emptyIcon;
    String emptyTitle;
    String emptyDesc;

    switch (_activeTabIndex) {
      case 1:
        currentList = _userReels;
        emptyTitle = 'No Reels Published';
        emptyDesc = 'No short video reels have been published yet.';
        emptyIcon = Icons.video_library_outlined;
        break;
      case 2:
        currentList = _userLive;
        emptyTitle = 'No Live Broadcasts';
        emptyDesc = 'There are no active or scheduled live streams right now.';
        emptyIcon = Icons.sensors_outlined;
        break;
      case 3:
        currentList = _userMentions;
        emptyTitle = 'No Mentions Found';
        emptyDesc = 'No tagged posts or mentions found for this profile.';
        emptyIcon = Icons.person_pin_outlined;
        break;
      case 0:
      default:
        currentList = _userPosts;
        emptyTitle = 'No Posts Yet';
        emptyDesc = 'This profile hasn\'t published any posts yet.';
        emptyIcon = Icons.grid_on_outlined;
        break;
    }

    if (currentList.isEmpty) {
      return CenteredEmptyStateWidget(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDesc,
        minHeight: 280,
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
        final isPinned = item['is_pinned'] == true;

        return GestureDetector(
          onTap: () => _showPostDetailModal(item),
          child: Container(
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
                        errorWidget: (context, url, error) => Container(
                          color: DesignTokens.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      ),
                      if (isPinned)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignTokens.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, color: Colors.white, size: 10),
                                SizedBox(width: 2),
                                Text(
                                  'Pinned',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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

class ActivityBadgeItem {
  final String id;
  final String title;
  final String shortTitle;
  final String level;
  final String description;
  final IconData icon;
  final Color color;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final String status;
  final String criteria;
  final String icon3dType;

  const ActivityBadgeItem({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.level,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.status,
    required this.criteria,
    required this.icon3dType,
  });
}

class _Badge3DToken extends StatelessWidget {
  final ActivityBadgeItem badge;
  final VoidCallback onTap;
  final bool isDark;
  final double size;

  const _Badge3DToken({
    required this.badge,
    required this.onTap,
    required this.isDark,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3D Volumetric Token Container
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.3),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    badge.gradientStart,
                    badge.gradientMid,
                    badge.gradientEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: badge.gradientEnd.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top Gloss Specular Highlight Arc
                  Positioned(
                    top: 1.5,
                    left: 3,
                    right: 3,
                    height: size * 0.36,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(size * 0.26),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.65),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center 3D Icon Glyph with Drop Shadow
                  Icon(
                    badge.icon,
                    color: Colors.white,
                    size: size * 0.52,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),

                  // Bottom Specular Edge Highlight
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: size * 0.4,
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Badge Short Title
            Text(
              badge.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserActivityBadgesSection extends StatelessWidget {
  final int userId;
  final String name;
  final String roleLabel;
  final Map<String, dynamic>? profileData;
  final bool isDark;
  final Color textPrimary;
  final Color? textSecondary;

  const _UserActivityBadgesSection({
    required this.userId,
    required this.name,
    required this.roleLabel,
    this.profileData,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  ActivityBadgeItem _mapBadgeFromBackend({
    required String slug,
    required String title,
    required String level,
    required String description,
    required String icon3dType,
    required String criteria,
  }) {
    IconData icon;
    Color color;
    Color gradStart;
    Color gradMid;
    Color gradEnd;
    String shortTitle;

    switch (icon3dType) {
      case '3d-cube':
        icon = Icons.view_in_ar_rounded;
        color = const Color(0xFF818CF8);
        gradStart = const Color(0xFF818CF8);
        gradMid = const Color(0xFF9333EA);
        gradEnd = const Color(0xFF4338CA);
        shortTitle = 'Web3';
        break;
      case '3d-shield':
        icon = Icons.shield_rounded;
        color = const Color(0xFF10B981);
        gradStart = const Color(0xFF34D399);
        gradMid = const Color(0xFF10B981);
        gradEnd = const Color(0xFF0F766E);
        shortTitle = 'Escrow';
        break;
      case '3d-trophy':
        icon = Icons.emoji_events_rounded;
        color = const Color(0xFF0284C7);
        gradStart = const Color(0xFF60A5FA);
        gradMid = const Color(0xFF0284C7);
        gradEnd = const Color(0xFF1D4ED8);
        shortTitle = 'Champion';
        break;
      case '3d-gem':
        icon = Icons.military_tech_rounded;
        color = const Color(0xFFE11D48);
        gradStart = const Color(0xFFF472B6);
        gradMid = const Color(0xFFE11D48);
        gradEnd = const Color(0xFF9F1239);
        shortTitle = 'Genesis';
        break;
      case '3d-badge':
        icon = Icons.verified_rounded;
        color = const Color(0xFFA855F7);
        gradStart = const Color(0xFFA78BFA);
        gradMid = const Color(0xFFC026D3);
        gradEnd = const Color(0xFF7C3AED);
        shortTitle = 'Storyteller';
        break;
      case '3d-award':
        icon = Icons.workspace_premium_rounded;
        color = const Color(0xFFD97706);
        gradStart = const Color(0xFFFDE047);
        gradMid = const Color(0xFFF59E0B);
        gradEnd = const Color(0xFFD97706);
        shortTitle = 'Merchant';
        break;
      case '3d-star':
      default:
        icon = Icons.star_rounded;
        color = const Color(0xFFF59E0B);
        gradStart = const Color(0xFFFBBF24);
        gradMid = const Color(0xFFF97316);
        gradEnd = const Color(0xFFB45309);
        shortTitle = 'Creator';
        break;
    }

    return ActivityBadgeItem(
      id: slug,
      title: title,
      shortTitle: shortTitle,
      level: level,
      description: description,
      icon: icon,
      color: color,
      gradientStart: gradStart,
      gradientMid: gradMid,
      gradientEnd: gradEnd,
      status: 'Verified',
      criteria: criteria.isNotEmpty ? criteria : 'Automated ecosystem verification',
      icon3dType: icon3dType,
    );
  }

  List<ActivityBadgeItem> _generateBadges() {
    final badges = <ActivityBadgeItem>[];

    // 1. Primary: Parse dynamic badges evaluated and returned from backend API
    final rawBadges = profileData?['badges'];
    if (rawBadges is List && rawBadges.isNotEmpty) {
      for (final item in rawBadges) {
        if (item is Map) {
          final mapItem = Map<String, dynamic>.from(item);
          final slug = mapItem['slug'] as String? ?? '';
          final name = mapItem['name'] as String? ?? '';
          final levelLabel = mapItem['level_label'] as String? ?? 'Verified';
          final desc = mapItem['description'] as String? ?? '';
          final icon3d = mapItem['icon_3d'] as String? ?? '3d-star';
          final ruleText = mapItem['criteria'] is Map
              ? (mapItem['criteria']['rule'] as String? ?? '')
              : '';

          badges.add(_mapBadgeFromBackend(
            slug: slug,
            title: name.isNotEmpty ? name : 'Activity Badge',
            level: levelLabel,
            description: desc,
            icon3dType: icon3d,
            criteria: ruleText,
          ));
        }
      }
      return badges;
    }

    // 2. Strict Fallback Logic based ONLY on actual profile properties (NO hardcoded grants!)
    final role = (profileData?['role'] as String? ?? roleLabel).toLowerCase();
    final isKycVerified = profileData?['kyc_status'] == 'verified';
    final postsCount = (profileData?['posts_count'] as num?)?.toInt() ?? 0;
    final followersCount = (profileData?['followers_count'] as num?)?.toInt() ?? 0;

    // Rule: Must be a genuine creator or vendor role
    if (role == 'creator' || role == 'vendor') {
      badges.add(_mapBadgeFromBackend(
        slug: 'creator_economy',
        title: 'Creator Economy Star',
        level: 'Master Creator · Level 2',
        description: 'Published interactive courses, digital assets and creator storefront offerings on MurihSpace.',
        icon3dType: '3d-star',
        criteria: 'Active creator or vendor account with published catalogue.',
      ));
    }

    // Rule: Must have completed real KYC identity verification
    if (isKycVerified) {
      badges.add(_mapBadgeFromBackend(
        slug: 'web3_pioneer',
        title: 'Web3 Pioneer',
        level: 'Smart Account · Tier 1',
        description: 'Verified smart wallet participant across decentralized governance & Web3 communities.',
        icon3dType: '3d-cube',
        criteria: 'KYC identity verified with linked smart account wallet.',
      ));
    }

    // Rule: Must have 20+ followers
    if (followersCount >= 20) {
      badges.add(_mapBadgeFromBackend(
        slug: 'community_leader',
        title: 'Community Champion',
        level: 'Top 5% Contributor',
        description: 'Consistent participant across discussion hubs, mutual spaces, and real-time community rooms.',
        icon3dType: '3d-trophy',
        criteria: 'Reached 20+ followers and active community interactions.',
      ));
    }

    // Rule: Must have 10+ posts
    if (postsCount >= 10) {
      badges.add(_mapBadgeFromBackend(
        slug: 'viral_publisher',
        title: 'Content Maestro',
        level: 'Top Storyteller',
        description: 'Published 10 or more viral posts, articles, and short reels across MurihSpace.',
        icon3dType: '3d-badge',
        criteria: 'Published 10 or more posts or reels.',
      ));
    }

    return badges;
  }

  void _showBadgeDetailSheet(BuildContext context, ActivityBadgeItem badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF1E222A) : Colors.white;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // 3D Badge Representation (Proportionally sized)
                _Badge3DToken(
                  badge: badge,
                  onTap: () {},
                  isDark: isDark,
                  size: 58,
                ),
                const SizedBox(height: 10),

                Text(
                  badge.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.level,
                    style: TextStyle(color: badge.color, fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282C35) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verification Rule',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              badge.criteria,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

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
                    child: const Text('Close Verification Details', style: TextStyle(fontWeight: FontWeight.w700)),
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

    // If no badges have been earned by the user, cleanly hide the section
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Badges',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 10),

        // Sleek compact 3D Badge Shelf
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (ctx, index) {
              final b = badges[index];
              return _Badge3DToken(
                badge: b,
                onTap: () => _showBadgeDetailSheet(context, b),
                isDark: isDark,
                size: 42,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> postData;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;
  final int authorId;

  const _PostDetailSheet({
    required this.postData,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatar,
    required this.authorId,
  });

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isSaved = false;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.postData['is_liked'] == true;
    _likesCount = (widget.postData['likes_count'] as num?)?.toInt() ?? 0;
    _commentsCount = (widget.postData['comments_count'] as num?)?.toInt() ?? 0;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final postId = widget.postData['id'];
    if (postId == null) return;
    try {
      final res = await ApiClient.instance.dio.get('/posts/$postId/comments');
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
          _comments = list;
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final postId = widget.postData['id'];
    if (postId == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await ApiClient.instance.dio.post('/posts/$postId/like');
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    final postId = widget.postData['id'];
    if (text.isEmpty || postId == null || _sendingComment) return;

    setState(() => _sendingComment = true);
    try {
      final res = await ApiClient.instance.dio.post(
        '/posts/$postId/comments',
        data: {'content': text},
      );
      final payload = ApiClient.instance.unwrap(res);
      final myUser = ref.read(authProvider).user;
      final newComment = payload is Map<String, dynamic>
          ? payload
          : {
              'id': DateTime.now().millisecondsSinceEpoch,
              'content': text,
              'created_at': DateTime.now().toIso8601String(),
              'user': {
                'id': myUser?.id ?? 0,
                'name': myUser?.name ?? 'Me',
                'username': myUser?.username ?? 'me',
                'avatar_url': myUser?.avatarUrl,
              },
            };

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _commentsCount += 1;
          _sendingComment = false;
        });
        _commentController.clear();
      }
    } catch (_) {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141720) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final mediaUrls = widget.postData['media_urls'] is List ? widget.postData['media_urls'] as List : [];
    final imageUrl = mediaUrls.isNotEmpty ? mediaUrls.first.toString() : null;
    final content = widget.postData['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(widget.postData['created_at']?.toString() ?? '');
    final timeStr = formatRelativeTime(createdAt);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag indicator & Close
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                      color: textSecondary,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Header: Author Avatar, Name, Handle, Time
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                          backgroundImage: widget.authorAvatar.isNotEmpty
                              ? NetworkImage(ApiClient.resolveUrl(widget.authorAvatar) ?? widget.authorAvatar)
                              : null,
                          child: widget.authorAvatar.isEmpty
                              ? const Icon(Icons.person, color: DesignTokens.primary, size: 22)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authorName,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                              ),
                              Text(
                                '@${widget.authorUsername} · $timeStr',
                                style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded),
                          color: textSecondary,
                          onPressed: () {
                            AppShare.showShareSheet(
                              context,
                              title: 'Share Post',
                              text: content,
                              url: Env.profileUrl(widget.authorUsername),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Post Media or Text Card
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: ApiClient.resolveUrl(imageUrl) ?? imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 240,
                            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                            child: const Center(child: CircularProgressIndicator.adaptive()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 240,
                            color: DesignTokens.primary.withValues(alpha: 0.1),
                            child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Buttons Row (Like, Comment, Share, Bookmark)
                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleLike,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _isLiked ? Colors.red : textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_likesCount',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, color: textSecondary, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '$_commentsCount',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.share_outlined, color: textSecondary, size: 20),
                          onPressed: () {
                            AppShare.showShareSheet(
                              context,
                              title: 'Share Post',
                              text: content,
                              url: Env.profileUrl(widget.authorUsername),
                            );
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _isSaved ? DesignTokens.primary : textSecondary,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() => _isSaved = !_isSaved);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isSaved ? 'Post saved to bookmarks' : 'Post removed from bookmarks'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Post Caption
                    if (content.isNotEmpty) ...[
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${widget.authorUsername} ',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textPrimary),
                            ),
                            TextSpan(
                              text: content,
                              style: TextStyle(fontSize: 13, color: textPrimary, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Divider(),
                    const SizedBox(height: 8),

                    // Comments Title
                    Text(
                      'Comments (${_comments.length})',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Comments List
                    if (_loadingComments)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator.adaptive()))
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No comments yet. Be the first to join the conversation!',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._comments.map((c) {
                        final commentUser = c['user'] is Map ? c['user'] as Map : null;
                        final cName = commentUser?['name'] as String? ?? 'User';
                        final cAvatar = commentUser?['avatar_url'] as String? ?? '';
                        final cContent = c['content'] as String? ?? '';
                        final cTime = formatRelativeTime(DateTime.tryParse(c['created_at']?.toString() ?? ''));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                                backgroundImage: cAvatar.isNotEmpty ? NetworkImage(ApiClient.resolveUrl(cAvatar) ?? cAvatar) : null,
                                child: cAvatar.isEmpty ? const Icon(Icons.person, size: 16, color: DesignTokens.primary) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(cName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textPrimary)),
                                        const SizedBox(width: 6),
                                        Text(cTime, style: TextStyle(fontSize: 11, color: textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(cContent, style: TextStyle(fontSize: 12, color: textPrimary, height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Bottom Comment Composer
              Container(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    top: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF8FAFC),
                        ),
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sendingComment
                        ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: DesignTokens.primary),
                            onPressed: _submitComment,
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

