import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../components/send_gift_dialog.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/friends_provider.dart';

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

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  String _friendshipStatus = 'none'; // 'none', 'pending_sent', 'pending_received', 'accepted', 'self'
  int? _requestId;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
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

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);
    final authUser = ref.watch(authProvider).user;
    final isSelf = authUser?.id == widget.userId;

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
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9500)),
            tooltip: 'Send Gift',
            onPressed: () => SendGiftDialog.show(
              context,
              recipientName: widget.name,
              recipientAvatar: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Sleek Cover Banner Header
          Container(
            height: 110,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF9500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Avatar with Gradient Ring & Online Presence Badge
                  OnlineAvatarBadge(
                    isOnline: true,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: bg,
                        backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                        child: widget.avatarUrl.isEmpty
                            ? Text(
                                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.name,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.username}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 6),
                  const OnlineStatusBadge(isOnline: true, showLabel: true),
                  const SizedBox(height: 8),

                  // Role Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.roleLabel.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 18),

                  // Interactive Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol('Posts', '$postsCount', textPrimary, textSecondary, () {}),
                      _statCol(
                        'Followers',
                        '$followersCount',
                        textPrimary,
                        textSecondary,
                        () => FollowersListDialog.show(context, title: '${widget.name}\'s Followers', isFollowersList: true, userId: widget.userId),
                      ),
                      _statCol(
                        'Following',
                        '$followingCount',
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
                              backgroundColor: isFollowing ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)) : const Color(0xFF007AFF),
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
                                        : const Color(0xFF007AFF)),
                                width: 1.5,
                              ),
                              foregroundColor: _friendshipStatus == 'accepted'
                                  ? const Color(0xFF34C759)
                                  : (_friendshipStatus == 'pending_sent'
                                      ? Colors.orange
                                      : const Color(0xFF007AFF)),
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
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF007AFF), size: 20),
                          tooltip: 'Message',
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Activity & Highlights Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Highlights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hub_rounded, color: Color(0xFF007AFF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Creator & Verified Member',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active contributor to Web3, Creator Economy & Vendor communities on MurihSpace.',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Real Creator Courses & Digital Goods Showcase
                _UserCoursesAndGoodsShowcase(userId: widget.userId, creatorName: widget.name),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
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
                color: const Color(0xFF007AFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_items.length} Published',
                style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 11),
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
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF007AFF)),
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
                                  ? const Color(0xFF007AFF).withOpacity(0.15)
                                  : const Color(0xFF5856D6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCourse ? 'COURSE' : 'DIGITAL GOOD',
                              style: TextStyle(
                                color: isCourse ? const Color(0xFF007AFF) : const Color(0xFF5856D6),
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
                        backgroundColor: const Color(0xFF007AFF),
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
