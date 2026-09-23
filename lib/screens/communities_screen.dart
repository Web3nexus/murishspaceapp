import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/community_manage_sheet.dart';
import '../components/group_info_sheet.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../models/community_models.dart';
import '../models/group_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/groups_provider.dart';
import 'community_create_dialog.dart';

/// Communities & Groups hub — My Space (created) / Communities / Groups
/// discovery with a shared IG-style search bar.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // React to tab changes from swipe as well as taps. Fires only once per
    // change, after the animation/index settles (indexIsChanging is false).
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _onTabChanged(_tab.index);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _routeSearch(String query) {
    final index = _tab.index;
    if (index == 1) {
      ref.read(discoverCommunitiesProvider.notifier).search(query);
    } else if (index == 2) {
      ref.read(discoverGroupsProvider.notifier).search(query);
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _routeSearch(val);
    });
  }

  void _onTabChanged(int index) {
    if (index == 1) {
      ref.read(myCommunitiesProvider.notifier).refresh();
    } else if (index == 2) {
      ref.read(myGroupsProvider.notifier).refresh();
    }
    _routeSearch(_searchQuery);
  }

  Future<void> _showCreateCommunity() async {
    final user = ref.read(authProvider).user;
    final role = user?.role ?? UserRole.member;
    final canCreate = role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin;

    if (!canCreate) {
      showRoleRestrictedCommunitySheet(context);
      return;
    }

    final community = await showCreateCommunityDialog(context);
    if (community == null || !mounted) return;
    ref.read(myCommunitiesProvider.notifier).refresh();
    _tab.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;
    final canCreate = role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFFAFAFA);
    final searchBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Spaces',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showCreateCommunity,
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: canCreate ? 'Create Group / Community' : 'Group Creation Info',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Color(0xFF8E8E93), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search communities & groups…',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : const Color(0xFF8E8E93),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tab,
                labelColor: const Color(0xFF007AFF),
                unselectedLabelColor: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                indicatorColor: const Color(0xFF007AFF),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'My Space'),
                  Tab(text: 'Communities'),
                  Tab(text: 'Groups'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MySpaceView(
            searchQuery: _searchQuery,
            onCreateCommunity: _showCreateCommunity,
            onDiscoverTap: () => _tab.animateTo(1),
          ),
          _CommunitiesTab(searchQuery: _searchQuery),
          _GroupsTab(searchQuery: _searchQuery),
        ],
      ),
    );
  }
}

/// Shared profile-strip avatar used by IG-style cards.
class _CircleLogo extends StatelessWidget {
  static const double size = 48;
  final String? imageUrl;
  final String initials;
  final IconData fallbackIcon;

  const _CircleLogo({
    required this.imageUrl,
    required this.initials,
    this.fallbackIcon = Icons.groups_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DesignTokens.primary, width: 1.4),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => _logoFallback(),
              )
            : _logoFallback(),
      ),
    );
  }

  Widget _logoFallback() => Container(
        color: DesignTokens.primarySoft,
        alignment: Alignment.center,
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: DesignTokens.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              )
            : Icon(fallbackIcon, color: DesignTokens.primary, size: size * 0.48),
      );
}

/// IG-style section label ("Your Communities", "Suggested for you").
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(
            color: DesignTokens.primary,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IG profile-style stats header shown at the top of My Space.
class _MySpaceHeader extends StatelessWidget {
  final int communityCount;
  final int groupCount;

  const _MySpaceHeader({
    required this.communityCount,
    required this.groupCount,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      title: 'My Space',
      subtitle: 'The communities & groups you created',
      rows: [
        _StatRow(icon: Icons.people_rounded, label: 'Communities', count: communityCount),
        _StatRow(icon: Icons.groups_rounded, label: 'Groups', count: groupCount),
        _StatRow(icon: Icons.visibility_rounded, label: 'Discover', count: communityCount + groupCount),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> rows;

  const _StatCard({required this.title, required this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111214) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.rLg),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF61758A)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _StatRow({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: DesignTokens.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : const Color(0xFF61758A),
            ),
          ),
        ],
      ),
    );
  }
}

/// IG-style action pill: "Join" / "Joined" / "Manage".
class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    this.icon = Icons.add_rounded,
    this.filled = true,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = destructive
        ? const Color(0xFFFF3B30)
        : (filled || !isDark) ? DesignTokens.primary : Colors.blue.shade300;
    return Material(
      color: filled ? DesignTokens.primary.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// My Space — created communities + created groups
// ─────────────────────────────────────────────────────────────────────────

class _MySpaceView extends ConsumerStatefulWidget {
  final String searchQuery;
  final VoidCallback onCreateCommunity;
  final VoidCallback onDiscoverTap;

  const _MySpaceView({
    this.searchQuery = '',
    required this.onCreateCommunity,
    required this.onDiscoverTap,
  });

  @override
  ConsumerState<_MySpaceView> createState() => _MySpaceViewState();
}

class _MySpaceViewState extends ConsumerState<_MySpaceView> {
  @override
  Widget build(BuildContext context) {
    final myState = ref.watch(myCommunitiesProvider);
    final groupsState = ref.watch(myGroupsProvider);
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;
    final canCreate = role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin;
    final myId = user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final createdCommunities = myState.communities
        .where((c) => myId != null && (c.userId == myId || c.creator?.id == myId))
        .toList();
    final createdGroups = groupsState.groups
        .where((g) => myId != null && (g.userRole == 'owner' || g.creator?.id == myId))
        .toList();

    final q = widget.searchQuery.trim().toLowerCase();
    final filteredCommunities = q.isEmpty
        ? createdCommunities
        : createdCommunities.where((c) {
            return c.name.toLowerCase().contains(q) ||
                (c.description?.toLowerCase().contains(q) ?? false) ||
                (c.category?.toLowerCase().contains(q) ?? false);
          }).toList();
    final filteredGroups = q.isEmpty
        ? createdGroups
        : createdGroups.where((g) {
            return g.name.toLowerCase().contains(q) ||
                (g.description?.toLowerCase().contains(q) ?? false);
          }).toList();

    final anyCreated = createdCommunities.isNotEmpty || createdGroups.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(myCommunitiesProvider.notifier).refresh();
        await ref.read(myGroupsProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          _MySpaceHeader(
            communityCount: createdCommunities.length,
            groupCount: createdGroups.length,
          ),
          if (canCreate)
            _CreatorActionRow(onCreateCommunity: widget.onCreateCommunity)
          else
            _MemberGuidance(onDiscoverTap: widget.onDiscoverTap, isDark: isDark),

          if (anyCreated && widget.searchQuery.trim().isNotEmpty && filteredGroups.isEmpty && filteredCommunities.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyStateWidget(
                icon: Icons.search_off_rounded,
                title: 'No matches found',
                description: 'Try a different keyword for your created spaces.',
              ),
            ),

          if (createdGroups.isNotEmpty) ...[
            _SectionLabel('My Groups'),
            ...filteredGroups.map((g) => _GroupRow(
                  group: g,
                  isOwner: g.userRole == 'owner',
                  trailing: _ActionPill(
                    label: 'Manage',
                    icon: Icons.tune_rounded,
                    filled: false,
                    onTap: () => GroupInfoSheet.show(context, g),
                  ),
                  onTap: () => GroupInfoSheet.show(context, g),
                )),
          ],

          if (createdCommunities.isNotEmpty) ...[
            _SectionLabel('My Communities'),
            ...filteredCommunities.map((c) {
              final isOwner = myId != null && (c.userId == myId || c.creator?.id == myId);
              return _CommunityRow(
                community: c,
                isOwner: isOwner,
                trailing: _ActionPill(
                  label: 'Manage',
                  icon: Icons.tune_rounded,
                  filled: false,
                  onTap: () => CommunityManageSheet.show(context, c),
                ),
                onTap: () => context.push('/app/community/${c.slug}'),
              );
            }),
          ],

          if (!anyCreated)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyStateWidget(
                icon: Icons.workspaces_outline,
                title: canCreate ? 'Launch your space' : 'No spaces yet',
                description: canCreate
                    ? 'Create communities and groups to build your audience and monetize courses.'
                    : 'Communities and groups you create will appear here.',
                actionLabel: canCreate ? 'Create Your First Space' : 'Discover Spaces',
                onAction: canCreate ? widget.onCreateCommunity : widget.onDiscoverTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _CreatorActionRow extends StatelessWidget {
  final VoidCallback onCreateCommunity;

  const _CreatorActionRow({required this.onCreateCommunity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onCreateCommunity,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Community / Group',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberGuidance extends StatelessWidget {
  final VoidCallback onDiscoverTap;
  final bool isDark;

  const _MemberGuidance({required this.onDiscoverTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141720) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF232936) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF007AFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onDiscoverTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member Group Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Explore and join any group freely. Creating new spaces is reserved for verified Creators and Vendors.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Discover spaces',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF007AFF)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared IG-style row cards
// ─────────────────────────────────────────────────────────────────────────

class _RowCard extends StatelessWidget {
  final Widget logo;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _RowCard({
    required this.logo,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111214) : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.rMd),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : const Color(0xFF61758A),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  final Community community;
  final bool isOwner;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _CommunityRow({
    required this.community,
    this.isOwner = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      logo: _CircleLogo(
        imageUrl: community.logoUrl,
        initials: community.initials,
        fallbackIcon: Icons.people_rounded,
      ),
      title: community.name,
      subtitle: isOwner
          ? '${community.membersCount} members · Owned by you'
          : '${community.membersCount} members',
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _GroupRow extends StatelessWidget {
  final Group group;
  final bool isOwner;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _GroupRow({
    required this.group,
    this.isOwner = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      logo: _CircleLogo(
        imageUrl: group.avatarUrl,
        initials: group.initials,
        fallbackIcon: Icons.groups_rounded,
      ),
      title: group.name,
      subtitle: isOwner
          ? '${group.membersCount} members · Owned by you'
          : '${group.membersCount} members',
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Communities tab — joined + discover
// ─────────────────────────────────────────────────────────────────────────

class _CommunitiesTab extends ConsumerStatefulWidget {
  final String searchQuery;

  const _CommunitiesTab({this.searchQuery = ''});

  @override
  ConsumerState<_CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<_CommunitiesTab> {
  Future<void> _join(BuildContext context, Community community, bool joined) async {
    if (joined) {
      context.push('/app/community/${community.slug}');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ApiClient.instance.dio.post('/communities/${community.id}/join');
      final parsed = MembershipStatus.fromJson(data.data);
      messenger.showSnackBar(
        SnackBar(
          content: Text(parsed.isPending
              ? 'Join request sent to the community creator.'
              : 'Joined ${community.name}!'),
        ),
      );
      ref.read(myCommunitiesProvider.notifier).refresh();
      ref.read(discoverCommunitiesProvider.notifier).refresh();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not join this community.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final discover = ref.watch(discoverCommunitiesProvider);
    final my = ref.watch(myCommunitiesProvider);
    final myIds = my.communities.map((c) => c.id).toSet();
    final myId = ref.watch(authProvider).user?.id;

    final joinedList = my.communities
        .where((c) => myId == null || (c.userId != myId && c.creator?.id != myId))
        .toList();

    if (discover.loading && discover.communities.isEmpty && joinedList.isEmpty) {
      return const LoadingStateWidget(message: 'Discovering communities…');
    }
    if (discover.error != null && discover.communities.isEmpty && joinedList.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load communities',
        description: discover.error!,
        onRetry: () => ref.read(discoverCommunitiesProvider.notifier).refresh(),
      );
    }

    final List<Widget> children = [];

    if (joinedList.isNotEmpty) {
      children.add(_SectionLabel('Your Communities'));
      children.addAll(joinedList.map((c) {
        final isOwner = myId != null && (c.userId == myId || c.creator?.id == myId);
        return _CommunityRow(
          community: c,
          isOwner: isOwner,
          trailing: _ActionPill(
            label: 'View',
            icon: Icons.arrow_forward_rounded,
            filled: false,
            onTap: () => context.push('/app/community/${c.slug}'),
          ),
          onTap: () => context.push('/app/community/${c.slug}'),
        );
      }));
      children.add(const SizedBox(height: 6));
    }

    final discoverList = discover.communities
        .where((c) => !myIds.contains(c.id))
        .toList();

    if (discoverList.isNotEmpty) {
      children.add(_SectionLabel(widget.searchQuery.trim().isEmpty
          ? 'Suggested Communities'
          : 'Search Results'));
      children.addAll(discoverList.map((c) {
        final isOwner = myId != null && (c.userId == myId || c.creator?.id == myId);
        final joined = myIds.contains(c.id) || isOwner;
        return _CommunityRow(
          community: c,
          isOwner: isOwner,
          trailing: joined
              ? _ActionPill(
                  label: 'Joined',
                  icon: Icons.check_rounded,
                  filled: false,
                  onTap: () => context.push('/app/community/${c.slug}'),
                )
              : _ActionPill(
                  label: 'Join',
                  icon: Icons.add_rounded,
                  filled: true,
                  onTap: () => _join(context, c, false),
                ),
          onTap: () => context.push('/app/community/${c.slug}'),
        );
      }));
      if (discover.hasMore) {
        children.add(Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: discover.loadingMore
                ? const CircularProgressIndicator(strokeWidth: 2)
                : TextButton(
                    onPressed: () => ref.read(discoverCommunitiesProvider.notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
          ),
        ));
      }
    }

    if (children.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.travel_explore_outlined,
        title: 'No communities found',
        description: 'Try a different search, or check other categories.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(discoverCommunitiesProvider.notifier).refresh();
        await ref.read(myCommunitiesProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Groups tab — joined + discover
// ─────────────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerStatefulWidget {
  final String searchQuery;

  const _GroupsTab({this.searchQuery = ''});

  @override
  ConsumerState<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<_GroupsTab> {
  Future<void> _join(BuildContext context, Group group, bool joined) async {
    if (joined) {
      GroupInfoSheet.show(context, group);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(discoverGroupsProvider.notifier).joinGroup(group.id);
    if (result is Map) {
      final status = result['status']?.toString() ?? 'joined';
      messenger.showSnackBar(
        SnackBar(
          content: Text(status == 'pending_approval'
              ? 'Join request submitted to the group admin.'
              : 'Joined ${group.name}!'),
        ),
      );
      ref.read(myGroupsProvider.notifier).refresh();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Could not join this group.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final discover = ref.watch(discoverGroupsProvider);
    final my = ref.watch(myGroupsProvider);
    final myIds = my.groups.map((g) => g.id).toSet();
    final joinedGroups = my.groups.where((g) => g.userRole != 'owner').toList();

    if (discover.loading && discover.groups.isEmpty && joinedGroups.isEmpty) {
      return const LoadingStateWidget(message: 'Discovering groups…');
    }
    if (discover.error != null && discover.groups.isEmpty && joinedGroups.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load groups',
        description: discover.error!,
        onRetry: () => ref.read(discoverGroupsProvider.notifier).refresh(),
      );
    }

    final List<Widget> children = [];

    if (joinedGroups.isNotEmpty) {
      children.add(_SectionLabel('Your Groups'));
      children.addAll(joinedGroups.map((g) => _GroupRow(
            group: g,
            trailing: _ActionPill(
              label: 'Leave',
              icon: Icons.logout_rounded,
              filled: false,
              destructive: true,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final left =
                    await ref.read(discoverGroupsProvider.notifier).leaveGroup(g.id);
                if (left) ref.read(myGroupsProvider.notifier).refresh();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(left
                          ? 'You left the group.'
                          : 'Could not leave this group. Please try again.'),
                    ),
                  );
                }
              },
            ),
            onTap: () => GroupInfoSheet.show(context, g),
          )));
      children.add(const SizedBox(height: 6));
    }

    final discoverList = discover.groups.where((g) => !myIds.contains(g.id)).toList();

    if (discoverList.isNotEmpty) {
      children.add(_SectionLabel(widget.searchQuery.trim().isEmpty
          ? 'Suggested Groups'
          : 'Search Results'));
      children.addAll(discoverList.map((g) {
        final joined = myIds.contains(g.id);
        return _GroupRow(
          group: g,
          isOwner: g.userRole == 'owner',
          trailing: joined
              ? _ActionPill(
                  label: 'Member',
                  icon: Icons.check_rounded,
                  filled: false,
                  onTap: () => GroupInfoSheet.show(context, g),
                )
              : _ActionPill(
                  label: g.hasPendingRequest ? 'Requested' : 'Join',
                  icon: g.hasPendingRequest ? Icons.schedule_rounded : Icons.add_rounded,
                  filled: !g.hasPendingRequest,
                  onTap: () => _join(context, g, false),
                ),
          onTap: () => GroupInfoSheet.show(context, g),
        );
      }));
      if (discover.hasMore) {
        children.add(Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: discover.loadingMore
                ? const CircularProgressIndicator(strokeWidth: 2)
                : TextButton(
                    onPressed: () => ref.read(discoverGroupsProvider.notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
          ),
        ));
      }
    }

    if (children.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_rounded,
        title: 'No groups found',
        description: 'Try a different search, or check other categories.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(discoverGroupsProvider.notifier).refresh();
        await ref.read(myGroupsProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: children,
      ),
    );
  }
}

/// Explanatory sheet for regular members when attempting to create groups or inquiring about roles.
void showRoleRestrictedCommunitySheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: Color(0xFF007AFF), size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group & Community Creation',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Reserved for Creators & Vendors',
                        style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'On MurihSpace, creating and hosting groups is unlocked for verified Creators and Vendors to build followings, publish exclusive feeds, and sell digital courses or products.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            _roleFeatureRow(Icons.check_circle_rounded, 'Members can freely discover and join any public community.', isDark),
            const SizedBox(height: 8),
            _roleFeatureRow(Icons.monetization_on_rounded, 'Creators and Vendors can launch communities and monetize courses.', isDark),
            const SizedBox(height: 8),
            _roleFeatureRow(Icons.videocam_rounded, 'Host live streams and interactive audio conference rooms.', isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/upgrade-account');
                },
                child: const Text(
                  'Upgrade to Creator / Vendor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Explore Public Communities',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _roleFeatureRow(IconData icon, String text, bool isDark) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF007AFF)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}