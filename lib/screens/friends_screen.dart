import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../config/env.dart';
import '../core/api_client.dart';
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
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(friendsProvider.notifier).searchSuggestions(val);
      }
    });
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
            content: Text(contacts.isNotEmpty
                ? 'Found ${contacts.length} registered contacts on MurihSpace!'
                : 'Contacts synced. No registered friends found yet.'),
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
    final profileUrl = Env.profileUrl(username);
    Clipboard.setData(ClipboardData(text: profileUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile invite link ($profileUrl) copied!'),
        backgroundColor: const Color(0xFF007AFF),
      ),
    );
  }

  void _showAddFriendModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return _AddFriendModalSheet(
          onOpenChat: (u) {
            Navigator.pop(modalCtx);
            _openChatWithUser(u);
          },
          onExploreSuggestions: () {
            Navigator.pop(modalCtx);
            _tab.animateTo(1);
          },
          onSyncContacts: () {
            Navigator.pop(modalCtx);
            _showContactPermissionDialog();
          },
          onShareLink: () {
            Navigator.pop(modalCtx);
            _shareProfileLink();
          },
        );
      },
    );
  }

  void _showMyQrCodeModal() {
    final user = ref.read(authProvider).user;
    final username = user?.username ?? 'user';
    final name = user?.name ?? 'MurihSpace User';
    final profileUrl = Env.profileUrl(username);

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
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Add Friend',
            onPressed: _showAddFriendModal,
          ),
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
            icon: const Icon(Icons.share_outlined, color: Color(0xFF007AFF)),
            tooltip: 'Share Profile Link',
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
                    onChanged: _onSearchChanged,
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
                                _onSearchChanged('');
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
                                                fontSize: 15,
                                                color: textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '@${user.username} · ${user.mutualCount} mutual friends',
                                              style: TextStyle(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const SizedBox(width: 60),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF007AFF),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ref.read(friendsProvider.notifier).acceptRequest(user);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Accepted ${user.name}\'s friend request!'),
                                              backgroundColor: const Color(0xFF34C759),
                                            ),
                                          );
                                        },
                                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                          foregroundColor: isDark ? Colors.white : Colors.black,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ref.read(friendsProvider.notifier).declineRequest(user);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Declined request from ${user.name}')),
                                          );
                                        },
                                        child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 2: Suggestions / Search ────────────────────────────────────
                filteredSuggestions.isEmpty
                    ? _buildEmptyState(
                        _searchQuery.isNotEmpty
                            ? 'No users found matching "$_searchQuery"'
                            : 'No suggestions available',
                        Icons.person_search_rounded,
                        textSecondary)
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
                                  onTap: () => context.push('/profile/user/${user.id}?name=${Uri.encodeComponent(user.name)}&username=${Uri.encodeComponent(user.username)}'),
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
                                    onTap: () => context.push('/profile/user/${user.id}?name=${Uri.encodeComponent(user.name)}&username=${Uri.encodeComponent(user.username)}'),
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
                                          '@${user.username}${user.mutualCount > 0 ? " · ${user.mutualCount} mutuals" : ""}',
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSuggestionActionButton(user, isDark),
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
                        itemCount: filteredFriends.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final user = filteredFriends[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF007AFF),
                                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                      ? Text(
                                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF).withOpacity(0.12),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFFF9500),
                                  backgroundImage: comm.coverUrl != null && comm.coverUrl!.isNotEmpty ? NetworkImage(comm.coverUrl!) : null,
                                  child: comm.coverUrl == null || comm.coverUrl!.isEmpty
                                      ? Text(
                                          comm.name.isNotEmpty ? comm.name[0].toUpperCase() : 'C',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comm.name,
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                                      ),
                                      Text(
                                        '${comm.memberCount} members · ${comm.category}',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    ref.read(myCommunitiesProvider.notifier).leaveCommunity(comm.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Left ${comm.name}')),
                                    );
                                  },
                                  child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Tab 5: Contacts Matched on MurihSpace ────────────────────────
                filteredContacts.isEmpty
                    ? _buildContactsEmptyState(isDark, textPrimary, textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredContacts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final contact = filteredContacts[i];
                          Color color;
                          try {
                            color = Color(int.parse(contact.avatarColorHex));
                          } catch (_) {
                            color = const Color(0xFF007AFF);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (contact.id > 0) {
                                      context.push('/profile/user/${contact.id}?name=${Uri.encodeComponent(contact.name)}&username=${Uri.encodeComponent(contact.username)}');
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: color,
                                    backgroundImage: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty ? NetworkImage(contact.avatarUrl!) : null,
                                    child: contact.avatarUrl == null || contact.avatarUrl!.isEmpty
                                        ? Text(
                                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (contact.id > 0) {
                                        context.push('/profile/user/${contact.id}?name=${Uri.encodeComponent(contact.name)}&username=${Uri.encodeComponent(contact.username)}');
                                      }
                                    },
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
                                          '${contact.phone.isNotEmpty ? "${contact.phone} · " : ""}@${contact.username}',
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildMatchedContactActionButton(contact, isDark),
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

  Widget _buildSuggestionActionButton(FriendUserItem user, bool isDark) {
    if (user.status == 'accepted') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => _openChatWithUser(user),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
        label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (user.status == 'pending_sent') {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF007AFF),
          side: const BorderSide(color: Color(0xFF007AFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () {
          ref.read(friendsProvider.notifier).cancelSentRequest(user);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancelled request to ${user.name}')),
          );
        },
        icon: const Icon(Icons.hourglass_top_rounded, size: 14),
        label: const Text('Requested', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (user.status == 'pending_received') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF34C759),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () {
          ref.read(friendsProvider.notifier).acceptRequest(user);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Accepted friend request from ${user.name}!'),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        },
        child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () {
          ref.read(friendsProvider.notifier).sendRequest(user);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${user.name}!'),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        },
        icon: const Icon(Icons.person_add_rounded, size: 16),
        label: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }
  }

  Widget _buildMatchedContactActionButton(MatchedContact contact, bool isDark) {
    if (contact.isAlreadyFriend || contact.status == 'accepted') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => _openChatWithUser(FriendUserItem(
          id: contact.id,
          name: contact.name,
          username: contact.username,
          avatarUrl: contact.avatarUrl,
        )),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
        label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (contact.status == 'pending_sent') {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF007AFF),
          side: const BorderSide(color: Color(0xFF007AFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded, size: 14),
        label: const Text('Sent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else {
      return ElevatedButton.icon(
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
                  avatarUrl: contact.avatarUrl,
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
      );
    }
  }

  Widget _buildContactsEmptyState(bool isDark, Color textPrimary, Color? textSecondary) {
    if (!_hasContactPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contacts_rounded, size: 48, color: Color(0xFF007AFF)),
              ),
              const SizedBox(height: 16),
              Text(
                'Sync Your Phone Contacts',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover friends, colleagues, and contacts from your phone who are already on MurihSpace.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _showContactPermissionDialog,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sync Contacts Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: textSecondary),
            const SizedBox(height: 14),
            Text(
              'No phone contacts matched yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'When people in your phone address book join MurihSpace, they will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
            ),
          ],
        ),
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

/// Bottom sheet modal to search, discover and send friend requests directly.
class _AddFriendModalSheet extends ConsumerStatefulWidget {
  final ValueChanged<FriendUserItem> onOpenChat;
  final VoidCallback onExploreSuggestions;
  final VoidCallback onSyncContacts;
  final VoidCallback onShareLink;

  const _AddFriendModalSheet({
    required this.onOpenChat,
    required this.onExploreSuggestions,
    required this.onSyncContacts,
    required this.onShareLink,
  });

  @override
  ConsumerState<_AddFriendModalSheet> createState() => _AddFriendModalSheetState();
}

class _AddFriendModalSheetState extends ConsumerState<_AddFriendModalSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;
  List<FriendUserItem> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    try {
      final dio = ApiClient.instance.dio;
      final res = await dio.get('/friends/search', queryParameters: {'q': query});
      final list = ApiClient.instance.unwrapList(res, (item) {
        final serverStatus = (item['status'] as String?) ?? 'none';
        return FriendUserItem.fromJson(item, status: serverStatus);
      });
      if (mounted) {
        setState(() {
          _results = list;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _searching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF007AFF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Friend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Search by username, email, or phone number',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF1F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              onSubmitted: _executeSearch,
              style: TextStyle(fontSize: 14, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. @username, name, email, or phone...',
                hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF007AFF), size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007AFF)),
                        ),
                      )
                    : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Results or Shortcuts
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF007AFF)),
              ),
            )
          else if (_hasSearched && _results.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.person_off_rounded, size: 40, color: textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'No user found matching "${_controller.text.trim()}"',
                      style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, i) {
                  final u = _results[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/profile/user/${u.id}?name=${Uri.encodeComponent(u.name)}&username=${Uri.encodeComponent(u.username)}');
                          },
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF5856D6),
                            backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty ? NetworkImage(u.avatarUrl!) : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/user/${u.id}?name=${Uri.encodeComponent(u.name)}&username=${Uri.encodeComponent(u.username)}');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                                ),
                                Text(
                                  '@${u.username}${u.mutualCount > 0 ? " · ${u.mutualCount} mutuals" : ""}',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildActionButton(u, isDark),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Ways to Connect',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: Icons.person_search_rounded,
                  title: 'Explore Suggested Friends',
                  subtitle: 'Browse creators and members you may know',
                  onTap: widget.onExploreSuggestions,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 8),
                _buildQuickActionTile(
                  icon: Icons.contacts_rounded,
                  title: 'Find Phone Contacts',
                  subtitle: 'Match friends from your address book',
                  onTap: widget.onSyncContacts,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 8),
                _buildQuickActionTile(
                  icon: Icons.link_rounded,
                  title: 'Share My Profile Link',
                  subtitle: 'Invite friends to connect directly with you',
                  onTap: widget.onShareLink,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(FriendUserItem user, bool isDark) {
    if (user.status == 'accepted') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => widget.onOpenChat(user),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
        label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (user.status == 'pending_sent') {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF007AFF),
          side: const BorderSide(color: Color(0xFF007AFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () async {
          await ref.read(friendsProvider.notifier).cancelSentRequest(user);
          setState(() {
            _results = _results.map((r) => r.id == user.id ? FriendUserItem(
              id: user.id,
              name: user.name,
              username: user.username,
              avatarUrl: user.avatarUrl,
              mutualCount: user.mutualCount,
              status: 'none',
            ) : r).toList();
          });
        },
        icon: const Icon(Icons.hourglass_top_rounded, size: 14),
        label: const Text('Requested', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (user.status == 'pending_received') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF34C759),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () async {
          await ref.read(friendsProvider.notifier).acceptRequest(user);
          setState(() {
            _results = _results.map((r) => r.id == user.id ? FriendUserItem(
              id: user.id,
              name: user.name,
              username: user.username,
              avatarUrl: user.avatarUrl,
              mutualCount: user.mutualCount,
              status: 'accepted',
            ) : r).toList();
          });
        },
        child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () async {
          await ref.read(friendsProvider.notifier).sendRequestToUserId(user.id);
          setState(() {
            _results = _results.map((r) => r.id == user.id ? FriendUserItem(
              id: user.id,
              name: user.name,
              username: user.username,
              avatarUrl: user.avatarUrl,
              mutualCount: user.mutualCount,
              status: 'pending_sent',
            ) : r).toList();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to ${user.name}!'),
                backgroundColor: const Color(0xFF34C759),
              ),
            );
          }
        },
        icon: const Icon(Icons.person_add_rounded, size: 16),
        label: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
    required Color? textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF007AFF), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
          ],
        ),
      ),
    );
  }
}


