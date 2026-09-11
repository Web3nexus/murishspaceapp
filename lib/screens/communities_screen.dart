import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/community_manage_sheet.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import 'community_create_dialog.dart';

/// Communities tab — my communities + public discovery with role-aware management and join/leave.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(discoverCommunitiesProvider.notifier).search(val);
      }
    });
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
    final bg = isDark ? Colors.black : const Color(0xFFF7FAFC);
    final searchBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFF3F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Communities',
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
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF8E8E93),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search communities & public channels…',
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
                                      color: isDark ? Colors.grey[400] : const Color(0xFF8E8E93),
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
              const SizedBox(height: 10),
              TabBar(
                controller: _tab,
                labelColor: const Color(0xFF007AFF),
                unselectedLabelColor: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
                indicatorColor: const Color(0xFF007AFF),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [Tab(text: 'My Space'), Tab(text: 'Public Channels')],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MyCommunitiesView(
            searchQuery: _searchQuery,
            onCreateCommunity: _showCreateCommunity,
            onDiscoverTap: () => _tab.animateTo(1),
          ),
          const _DiscoverView(),
        ],
      ),
    );
  }
}

class _MyCommunitiesView extends ConsumerStatefulWidget {
  final String searchQuery;
  final VoidCallback onCreateCommunity;
  final VoidCallback onDiscoverTap;

  const _MyCommunitiesView({
    this.searchQuery = '',
    required this.onCreateCommunity,
    required this.onDiscoverTap,
  });

  @override
  ConsumerState<_MyCommunitiesView> createState() => _MyCommunitiesViewState();
}

class _MyCommunitiesViewState extends ConsumerState<_MyCommunitiesView> {
  int _filterIndex = 0; // 0 = All Joined, 1 = Created by Me

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myCommunitiesProvider);
    final notifier = ref.read(myCommunitiesProvider.notifier);
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;
    final canCreate = role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin;
    final myId = user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.loading && state.communities.isEmpty) {
      return const LoadingStateWidget(message: 'Loading communities…');
    }
    if (state.error != null && state.communities.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load communities',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }

    final createdList = state.communities
        .where((c) => myId != null && (c.userId == myId || c.creator?.id == myId))
        .toList();

    final targetList = _filterIndex == 1 ? createdList : state.communities;

    final filtered = widget.searchQuery.trim().isEmpty
        ? targetList
        : targetList.where((c) {
            final q = widget.searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.description?.toLowerCase().contains(q) ?? false) ||
                (c.category?.toLowerCase().contains(q) ?? false);
          }).toList();

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 1. Role-aware banner at the top of My Space
          if (canCreate)
            _buildCreatorManagementHub(context, role, createdList.length, isDark)
          else
            _buildMemberGuidanceCard(context, isDark),

          // 2. Filter chips for Creators/Vendors or if user created communities
          if (canCreate || createdList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Joined (${state.communities.length})'),
                    selected: _filterIndex == 0,
                    onSelected: (selected) {
                      if (selected) setState(() => _filterIndex = 0);
                    },
                    selectedColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: _filterIndex == 0 ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text('Created by Me (${createdList.length})'),
                      ],
                    ),
                    selected: _filterIndex == 1,
                    onSelected: (selected) {
                      if (selected) setState(() => _filterIndex = 1);
                    },
                    selectedColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: _filterIndex == 1 ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. List of communities or empty state
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _filterIndex == 1
                  ? EmptyStateWidget(
                      icon: Icons.hub_outlined,
                      title: 'No groups created yet',
                      description: 'Launch your first community or group to build your audience and monetize courses.',
                      actionLabel: 'Create Your First Group',
                      onAction: widget.onCreateCommunity,
                    )
                  : EmptyStateWidget(
                      icon: Icons.groups_outlined,
                      title: widget.searchQuery.isNotEmpty ? 'No matches found' : 'No communities yet',
                      description: widget.searchQuery.isNotEmpty
                          ? 'No joined communities match "${widget.searchQuery}".'
                          : 'You haven\'t joined any communities yet. Discover public channels to join!',
                      actionLabel: 'Discover Communities',
                      onAction: widget.onDiscoverTap,
                    ),
            )
          else
            ...filtered.map((c) {
              final isOwner = myId != null && (c.userId == myId || c.creator?.id == myId);
              return _CommunityCard(community: c, isOwner: isOwner);
            }),
        ],
      ),
    );
  }

  Widget _buildCreatorManagementHub(BuildContext context, UserRole role, int createdCount, bool isDark) {
    final roleName = role == UserRole.vendor ? 'Vendor' : 'Creator';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_rounded, color: Color(0xFF007AFF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$roleName Group Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$createdCount Managed',
                        style: const TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Launch groups, review join requests, and moderate feeds.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onCreateCommunity,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16),
                SizedBox(width: 2),
                Text('New Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberGuidanceCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141720) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF232936) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF007AFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                  'You can explore and join any group freely. Creating and hosting new communities is reserved for verified Creators and Vendors.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => context.push('/upgrade-account'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Apply to become a Creator / Vendor',
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Community community;
  final bool isOwner;

  const _CommunityCard({required this.community, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderCol = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF61758A);

    return InkWell(
      onTap: () => context.push('/app/community/${community.slug}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            CommunityLogo(community: community, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, size: 11, color: Color(0xFF007AFF)),
                              SizedBox(width: 2),
                              Text(
                                'Owner',
                                style: TextStyle(
                                  color: Color(0xFF007AFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${community.membersCount} members',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  if (community.description != null && community.description!.isNotEmpty)
                    Text(
                      community.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (isOwner)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
                  foregroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => CommunityManageSheet.show(context, community),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.chevron_right, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DiscoverView extends ConsumerWidget {
  const _DiscoverView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverCommunitiesProvider);
    final myIds = ref.watch(myCommunitiesProvider).communities.map((c) => c.id).toSet();
    final notifier = ref.read(discoverCommunitiesProvider.notifier);
    final user = ref.watch(authProvider).user;
    final myId = user?.id;

    return _discoverBody(context, ref, state, myIds, notifier, myId);
  }

  Widget _discoverBody(
    BuildContext context,
    WidgetRef ref,
    DiscoverState state,
    Set<int> myIds,
    DiscoverCommunitiesNotifier notifier,
    int? myId,
  ) {
    if (state.loading && state.communities.isEmpty) {
      return const LoadingStateWidget(message: 'Discovering communities…');
    }
    if (state.error != null && state.communities.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load communities',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }
    if (state.communities.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.travel_explore_outlined,
        title: 'No communities found',
        description: 'Try a different search, or discover other categories.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: state.communities.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        if (i >= state.communities.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: state.loadingMore
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : TextButton(onPressed: () => notifier.loadMore(), child: const Text('Load more')),
            ),
          );
        }
        final community = state.communities[i];
        final isOwner = myId != null && (community.userId == myId || community.creator?.id == myId);
        final joined = myIds.contains(community.id) || isOwner;
        return _DiscoverCard(
          community: community,
          joined: joined,
          isOwner: isOwner,
          onJoin: () => _join(context, ref, community, joined),
        );
      },
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, Community community, bool joined) async {
    if (joined) {
      context.push('/app/community/${community.slug}');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ApiClient.instance.dio.post('/communities/${community.id}/join');
      final data = response.data;
      final parsed = MembershipStatus.fromJson(data);
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not join this community.')),
      );
    }
  }
}

class _DiscoverCard extends StatelessWidget {
  final Community community;
  final bool joined;
  final bool isOwner;
  final VoidCallback onJoin;

  const _DiscoverCard({
    required this.community,
    required this.joined,
    this.isOwner = false,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderCol = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF61758A);

    return InkWell(
      onTap: () => context.push('/app/community/${community.slug}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            CommunityLogo(community: community, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${community.membersCount} members',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF007AFF)),
                tooltip: 'Manage Community',
                onPressed: () => CommunityManageSheet.show(context, community),
              ),
            joined
                ? OutlinedButton(
                    onPressed: onJoin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6)),
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: const Text('Joined ✓'),
                  )
                : FilledButton(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: const Text('Join'),
                  ),
          ],
        ),
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
                    color: const Color(0xFF007AFF).withOpacity(0.12),
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
