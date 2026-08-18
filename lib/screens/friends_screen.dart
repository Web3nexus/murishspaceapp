import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/contacts_service.dart';
import '../providers/chat_provider.dart';
import 'user_profile_screen.dart';

/// Modern Redesigned Friends, Connections & Phone Contacts Matching Hub.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _hasContactPermission = false;
  bool _isSyncingContacts = false;
  List<MatchedContact> _matchedContacts = [];

  final List<_FriendUser> _requests = [
    _FriendUser(
      id: 101,
      name: 'David Miller',
      username: 'david_m',
      title: 'Software Architect',
      mutualCount: 12,
      avatarColor: const Color(0xFF007AFF),
    ),
    _FriendUser(
      id: 102,
      name: 'Sophia Chen',
      username: 'sophia_c',
      title: 'UI/UX Designer',
      mutualCount: 8,
      avatarColor: const Color(0xFF5856D6),
    ),
  ];

  final List<_FriendUser> _suggestions = [
    _FriendUser(
      id: 103,
      name: 'Kemi Adebayo',
      username: 'kemi_brand',
      title: 'Fashion Creator & Merchant',
      mutualCount: 34,
      avatarColor: const Color(0xFFFF9500),
    ),
    _FriendUser(
      id: 104,
      name: 'Tunde Bakare',
      username: 'tunde_dev',
      title: 'Flutter Developer',
      mutualCount: 19,
      avatarColor: const Color(0xFF34C759),
    ),
    _FriendUser(
      id: 105,
      name: 'Amara Williams',
      username: 'amara_w',
      title: 'Digital Marketing Strategist',
      mutualCount: 42,
      avatarColor: const Color(0xFFFF2D55),
    ),
  ];

  final List<_FriendUser> _friends = [
    _FriendUser(
      id: 201,
      name: 'Alex Johnson',
      username: 'alex_j',
      title: 'Full-stack Developer',
      mutualCount: 24,
      isOnline: true,
      avatarColor: const Color(0xFF007AFF),
    ),
    _FriendUser(
      id: 202,
      name: 'Elena Rostova',
      username: 'elena_r',
      title: 'Product Manager',
      mutualCount: 45,
      isOnline: true,
      avatarColor: const Color(0xFF5856D6),
    ),
    _FriendUser(
      id: 203,
      name: 'Marcus Wright',
      username: 'marcus_w',
      title: 'Creator & Streamer',
      mutualCount: 110,
      isOnline: false,
      avatarColor: const Color(0xFFFF9500),
    ),
    _FriendUser(
      id: 204,
      name: 'Zoe Martinez',
      username: 'zoe_m',
      title: 'Web3 & Escrow Trader',
      mutualCount: 18,
      isOnline: true,
      avatarColor: const Color(0xFF5AC8FA),
    ),
  ];

  final List<Map<String, dynamic>> _communities = [
    {
      'name': 'Lagos Tech Creators',
      'members': '2.4k members',
      'icon': Icons.groups_rounded,
      'color': const Color(0xFF007AFF),
      'isMember': true,
    },
    {
      'name': 'Flutter & Mobile Developers',
      'members': '5.8k members',
      'icon': Icons.code_rounded,
      'color': const Color(0xFF34C759),
      'isMember': true,
    },
    {
      'name': 'MurihSpace Escrow Merchants',
      'members': '1.1k members',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFFF9500),
      'isMember': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkContactPermission();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkContactPermission() async {
    final granted = await ContactsService.instance.hasPermission();
    if (granted) {
      final contacts = await ContactsService.instance.syncContacts();
      if (mounted) {
        setState(() {
          _hasContactPermission = true;
          _matchedContacts = contacts;
        });
      }
    }
  }

  void _showContactPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contacts_rounded, color: Color(0xFF007AFF), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Contacts Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Text(
            'MurihSpace will securely match your phone contacts to help you find friends, vendors, and creators you already know.\n\nYour contacts are encrypted and never shared.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Not Now', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isSyncingContacts = true);
                await ContactsService.instance.requestPermission();
                final contacts = await ContactsService.instance.syncContacts();
                if (mounted) {
                  setState(() {
                    _hasContactPermission = true;
                    _isSyncingContacts = false;
                    _matchedContacts = contacts;
                  });
                  _tab.animateTo(4); // Switch to Contacts tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Contacts synced! Found ${contacts.length} friends on MurihSpace.'),
                      backgroundColor: const Color(0xFF34C759),
                    ),
                  );
                }
              },
              child: const Text('Allow Access', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openChatWithUser(_FriendUser user) async {
    final conversation = await ref.read(conversationsProvider.notifier).openDirectChat(
          user.id,
          name: user.name,
          username: user.username,
        );

    if (conversation != null && mounted) {
      context.push('/app/conversation/${conversation.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat opened with ${user.name}'),
          backgroundColor: const Color(0xFF007AFF),
        ),
      );
    }
  }

  void _shareProfileLink() {
    Clipboard.setData(const ClipboardData(text: 'https://murihspace.com/user/samuel'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile invite link copied to clipboard!'),
        backgroundColor: Color(0xFF007AFF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final filteredRequests = _requests
        .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredSuggestions = _suggestions
        .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredFriends = _friends
        .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredContacts = _matchedContacts
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery) || c.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Friends & Connections',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Sync Phone Contacts',
            onPressed: _showContactPermissionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF007AFF)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code scanner ready')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF007AFF)),
            onPressed: _shareProfileLink,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search friends, phone contacts, or handle...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),

              // TabBar Navigation with Contacts Tab
              TabBar(
                controller: _tab,
                isScrollable: true,
                labelColor: const Color(0xFF007AFF),
                unselectedLabelColor: textSecondary,
                indicatorColor: const Color(0xFF007AFF),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [
                  Tab(text: 'Requests (${_requests.length})'),
                  Tab(text: 'Suggestions (${_suggestions.length})'),
                  Tab(text: 'My Friends (${_friends.length})'),
                  Tab(text: 'Communities (${_communities.length})'),
                  Tab(text: 'Contacts (${_matchedContacts.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Contact Sync Top Banner (If permission not granted yet)
          if (!_hasContactPermission)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.contacts_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find Friends from Contacts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Discover contacts on your phone who are already on MurihSpace',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _showContactPermissionDialog,
                    child: _isSyncingContacts
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── Tab 1: Requests ───────────────────────────────────────────────
                filteredRequests.isEmpty
                    ? _buildEmptyState('No pending requests', Icons.mark_email_read_rounded, textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRequests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final user = filteredRequests[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: user.avatarColor,
                                      child: Text(
                                        user.name[0],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${user.title} · ${user.mutualCount} mutual friends',
                                            style: TextStyle(fontSize: 12, color: textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF007AFF),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _friends.add(user);
                                            _requests.removeWhere((u) => u.id == user.id);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Accepted ${user.name}\'s friend request!'),
                                              backgroundColor: const Color(0xFF34C759),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.check_rounded, size: 18),
                                        label: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                          foregroundColor: isDark ? Colors.white : Colors.black,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _requests.removeWhere((u) => u.id == user.id);
                                          });
                                        },
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 2: Suggestions ────────────────────────────────────────────
                filteredSuggestions.isEmpty
                    ? _buildEmptyState('No suggestions available', Icons.person_search_rounded, textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSuggestions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final user = filteredSuggestions[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: user.avatarColor,
                                  child: Text(
                                    user.name[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${user.title} · ${user.mutualCount} mutuals',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                    foregroundColor: const Color(0xFF007AFF),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Friend request sent to ${user.name}')),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 3: My Friends ──────────────────────────────────────────────
                filteredFriends.isEmpty
                    ? _buildEmptyState('No friends found', Icons.people_outline_rounded, textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredFriends.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final user = filteredFriends[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: user.avatarColor,
                                      child: Text(
                                        user.name[0],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                    if (user.isOnline)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: cardBg, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '@${user.username} · ${user.title}',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF007AFF), size: 18),
                                  ),
                                  onPressed: () => _openChatWithUser(user),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 4: Communities ─────────────────────────────────────────────
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _communities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final comm = _communities[i];
                    final isMember = comm['isMember'] as bool;
                    final color = comm['color'] as Color;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(comm['icon'] as IconData, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comm['name'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  comm['members'] as String,
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMember
                                  ? (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB))
                                  : const Color(0xFF007AFF),
                              foregroundColor: isMember ? (isDark ? Colors.white : Colors.black) : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _communities[i]['isMember'] = !isMember;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isMember ? 'Left community' : 'Joined community!')),
                              );
                            },
                            child: Text(
                              isMember ? 'Joined' : 'Join',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Tab 5: Contacts Matched on MurihSpace ────────────────────────
                filteredContacts.isEmpty
                    ? _buildEmptyState(
                        _hasContactPermission ? 'No phone contacts found' : 'Permission needed to view contacts',
                        Icons.contacts_rounded,
                        textSecondary,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredContacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final contact = filteredContacts[i];
                          final color = Color(int.parse(contact.avatarColorHex));
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: color,
                                  child: Text(
                                    contact.name[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${contact.phone} · @${contact.username}',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Friend request sent to ${contact.name} (${contact.phone})'),
                                        backgroundColor: const Color(0xFF34C759),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon, Color? color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FriendUser {
  final int id;
  final String name;
  final String username;
  final String title;
  final int mutualCount;
  final bool isOnline;
  final Color avatarColor;

  _FriendUser({
    required this.id,
    required this.name,
    required this.username,
    required this.title,
    required this.mutualCount,
    this.isOnline = false,
    required this.avatarColor,
  });
}
