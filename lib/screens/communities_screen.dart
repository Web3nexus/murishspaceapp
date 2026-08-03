import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';

/// Communities tab — my communities + public discovery with join/leave.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canCreate = user != null && user.role.isSeller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelColor: DesignTokens.primaryDark,
          unselectedLabelColor: DesignTokens.textSecondary,
          indicatorColor: DesignTokens.primary,
          tabs: const [Tab(text: 'My'), Tab(text: 'Discover')],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateCommunity(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: const [
          _MyCommunitiesView(),
          _DiscoverView(),
        ],
      ),
    );
  }

  Future<void> _showCreateCommunity(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final category = TextEditingController();
    var visibility = 'public';
    var pricingType = 'free';
    final price = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create community'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 8),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (v) => setState(() => visibility = v ?? 'public'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: pricingType,
                  decoration: const InputDecoration(labelText: 'Pricing'),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (v) => setState(() => pricingType = v ?? 'free'),
                ),
                if (pricingType == 'paid') ...[
                  const SizedBox(height: 8),
                  TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (MUR)')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A community name is required.')),
      );
      return;
    }
    try {
      await ApiClient.instance.dio.post('/my-communities', data: {
        'name': name.text.trim(),
        'description': description.text.trim().isEmpty ? null : description.text.trim(),
        'category': category.text.trim().isEmpty ? 'General' : category.text.trim(),
        'visibility': visibility,
        'pricing_type': pricingType,
        if (pricingType == 'paid') 'price_amount': double.tryParse(price.text) ?? 0,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community created!')),
      );
      ref.read(myCommunitiesProvider.notifier).refresh();
      _tab.animateTo(0);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the community.')),
      );
    }
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
            _Logo(community: community, size: 46),
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
            _Logo(community: community, size: 46),
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

class _Logo extends StatelessWidget {
  final Community community;
  final double size;

  const _Logo({required this.community, required this.size});

  @override
  Widget build(BuildContext context) {
    final logoUrl = community.logoUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: DesignTokens.primarySoft,
      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
      child: logoUrl == null || logoUrl.isEmpty
          ? Text(
              community.initials,
              style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700, fontSize: 16),
            )
          : null,
    );
  }
}
