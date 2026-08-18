import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/community_manage_sheet.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import 'community_create_dialog.dart';

/// Communities tab — my communities + public discovery with join/leave.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canCreate = user != null && user.role.isSeller;
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
          if (canCreate)
            IconButton(
              onPressed: () => _showCreateCommunity(),
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: isDark ? Colors.white : Colors.black,
              ),
              tooltip: 'Create Community',
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
                      Icon(
                        Icons.search_rounded,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search communities & public channels…',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                            ),
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
        children: const [
          _MyCommunitiesView(),
          _DiscoverView(),
        ],
      ),
    );
  }

  Future<void> _showCreateCommunity() async {
    final community = await showCreateCommunityDialog(context);
    if (community == null || !mounted) return;
    ref.read(myCommunitiesProvider.notifier).refresh();
    _tab.animateTo(0);
  }
}

class _MyCommunitiesView extends ConsumerWidget {
  const _MyCommunitiesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCommunitiesProvider);
    final notifier = ref.read(myCommunitiesProvider.notifier);

    if (state.loading && state.communities.isEmpty) {
      return const LoadingStateWidget(message: 'Loading communities…');
    }
    if (state.error != null && state.communities.isEmpty) {
      return ErrorStateWidget(title: 'Could not load communities', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.communities.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'No communities yet',
        description: 'Join communities from the Discover tab, or create your own.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.communities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _CommunityCard(community: state.communities[i]),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Community community;

  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/app/community/${community.slug}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: DesignTokens.border),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${community.membersCount} members',
                    style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                  ),
                  if (community.description != null && community.description!.isNotEmpty)
                    Text(
                      community.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DiscoverView extends ConsumerStatefulWidget {
  const _DiscoverView();

  @override
  ConsumerState<_DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<_DiscoverView> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverCommunitiesProvider);
    final myIds = ref.watch(myCommunitiesProvider).communities.map((c) => c.id).toSet();
    final notifier = ref.read(discoverCommunitiesProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _search,
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => notifier.search(value));
            },
            decoration: InputDecoration(
              hintText: 'Search communities…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: DesignTokens.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                borderSide: const BorderSide(color: DesignTokens.border),
              ),
            ),
          ),
        ),
        Expanded(child: _discoverBody(context, state, myIds, notifier)),
      ],
    );
  }

  Widget _discoverBody(BuildContext context, DiscoverState state, Set<int> myIds, DiscoverCommunitiesNotifier notifier) {
    if (state.loading && state.communities.isEmpty) {
      return const LoadingStateWidget(message: 'Discovering communities…');
    }
    if (state.error != null && state.communities.isEmpty) {
      return ErrorStateWidget(title: 'Could not load communities', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.communities.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.travel_explore_outlined,
        title: 'No communities found',
        description: 'Try a different search, or create your own community.',
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
        final joined = myIds.contains(community.id);
        return _DiscoverCard(
          community: community,
          joined: joined,
          onJoin: () => _join(community, joined),
        );
      },
    );
  }

  Future<void> _join(Community community, bool joined) async {
    if (joined) {
      ref.read(discoverCommunitiesProvider.notifier).refresh();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ApiClient.instance.dio.post('/communities/${community.id}/join');
      final data = response.data;
      final status = data is Map<String, dynamic> ? data['status'] : null;
      messenger.showSnackBar(
        SnackBar(
          content: Text(status == 'pending'
              ? 'Join request sent to the community creator.'
              : 'Joined ${community.name}!'),
        ),
      );
      ref.read(myCommunitiesProvider.notifier).refresh();
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
  final VoidCallback onJoin;

  const _DiscoverCard({
    required this.community,
    required this.joined,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/app/community/${community.slug}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: DesignTokens.border),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${community.membersCount} members',
                    style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Manage Community',
              onPressed: () => CommunityManageSheet.show(context, community),
            ),
            joined
                ? OutlinedButton(onPressed: onJoin, child: const Text('Joined'))
                : FilledButton(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.primary),
                    child: const Text('Join'),
                  ),
          ],
        ),
      ),
    );
  }
}
