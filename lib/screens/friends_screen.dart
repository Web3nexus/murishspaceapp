import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../core/contacts_service.dart';
import '../core/permissions_service.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../providers/friends_provider.dart';
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

  void _showContactPermissionDialog() async {
    final granted = await ref.read(permissionsProvider.notifier).ensureContacts(context);
    if (!granted) return;

    await ContactsService.instance.requestPermission();

    if (mounted) {
      setState(() => _isSyncingContacts = true);
      final contacts = await ContactsService.instance.syncContacts();
      if (mounted) {
        setState(() {
          _isSyncingContacts = false;
          _hasContactPermission = true;
          _matchedContacts = contacts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${contacts.length} registered contacts on MurihSpace!'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    }
  }

  Future<void> _openChatWithUser(FriendUserItem user) async {
    final conversation = await ref.read(conversationsProvider.notifier).openDirectChat(
          user.id,
          name: user.name,
          username: user.username,
          avatarUrl: user.avatarUrl,
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
    final user = ref.read(authProvider).user;
    final username = user?.username ?? 'user';
    final profileUrl = 'https://murihspace.com/u/$username';
    Clipboard.setData(ClipboardData(text: profileUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile invite link ($profileUrl) copied!'),
        backgroundColor: const Color(0xFF007AFF),
      ),
    );
  }

  void _showMyQrCodeModal() {
    final user = ref.read(authProvider).user;
    final username = user?.username ?? 'user';
    final name = user?.name ?? 'MurihSpace User';
    final profileUrl = 'https://murihspace.com/u/$username';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

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
                'My Profile QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              Text(
                'Scan to connect with @$username on MurihSpace',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 20),

              // QR Code Graphic Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 180, color: Color(0xFF007AFF)),
                    const SizedBox(height: 12),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text('@$username', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: profileUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Profile link copied: $profileUrl')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final friendsState = ref.watch(friendsProvider);
    final communitiesState = ref.watch(myCommunitiesProvider);

    final requests = friendsState.requests;
    final suggestions = friendsState.suggestions;
    final friends = friendsState.friends;
    final communities = communitiesState.communities;

    final filteredRequests = requests
        .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredSuggestions = suggestions
        .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredFriends = friends
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
            tooltip: 'My QR Code',
            onPressed: _showMyQrCodeModal,
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
                  Tab(text: 'Requests (${requests.length})'),
                  Tab(text: 'Suggestions (${suggestions.length})'),
                  Tab(text: 'My Friends (${friends.length})'),
                  Tab(text: 'Communities (${communities.length})'),
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredRequests.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final user = filteredRequests[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/profile/user/${user.id}?name=${user.name}&username=${user.username}'),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: const Color(0xFF007AFF),
                                        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                            ? Text(
                                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                              )
                                            : null,
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
                                          ref.read(friendsProvider.notifier).acceptRequest(user);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Accepted ${user.name}\'s friend request!'),
                                              backgroundColor: const Color(0xFF34C759),
                                            ),
                                          );
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ref.read(friendsProvider.notifier).declineRequest(user);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Declined request from ${user.name}')),
                                          );
                                        },
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredSuggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final user = filteredSuggestions[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/profile/user/${user.id}?name=${user.name}&username=${user.username}'),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFF5856D6),
                                    backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                        ? Text(
                                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/profile/user/${user.id}?name=${user.name}&username=${user.username}'),
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
                                          '${user.title ?? 'Creator'} · ${user.mutualCount} mutuals',
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                    foregroundColor: const Color(0xFF007AFF),
                                    elevation: 0,
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(0xFF007AFF),
                                        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                            ? Text(
                                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF34C759),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: cardBg, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/profile/user/${user.id}?name=${user.name}&username=${user.username}'),
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
                                          '@${user.username} · ${user.title ?? 'Friend'}',
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF007AFF), size: 16),
                                  ),
                                  onPressed: () => _openChatWithUser(user),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 4: Communities ─────────────────────────────────────────────
                communities.isEmpty
                    ? _buildEmptyState('No communities joined yet', Icons.groups_rounded, textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: communities.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final comm = communities[i];
                                        '${comm.memberCount} members · ${comm.category}',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isMember
                                        ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6))
                                        : const Color(0xFF007AFF),
                                    foregroundColor: isMember ? (isDark ? Colors.white : Colors.black) : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    if (isMember) {
                                      ref.read(myCommunitiesProvider.notifier).leaveCommunity(comm.id);
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 5: Contacts Matched on MurihSpace ────────────────────────
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredContacts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final contact = filteredContacts[i];
                          final color = Color(int.parse(contact.avatarColorHex));
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: color,
                                  child: Text(
                                    contact.name[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                                    ref.read(friendsProvider.notifier).sendRequest(
                                          FriendUserItem(
                                            id: contact.id,
                                            name: contact.name,
                                            username: contact.username,
                                            title: 'Phone Contact',
                                          ),
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Friend request sent to ${contact.name} (@${contact.username})'),
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

