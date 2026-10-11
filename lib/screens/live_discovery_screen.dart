import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/go_live_setup_dialog.dart';
import '../components/kyc_live_gate_dialog.dart';
import '../components/live_now_rail.dart';
import '../components/live_stream_card.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/live_discovery_provider.dart';

/// Browse every broadcast that is live right now (`GET /live`).
///
/// Mirrors the web discovery page: a responsive grid of live tiles, pull to
/// refresh, infinite scroll, and — when the airwaves are quiet — a call to
/// start your own broadcast.
class LiveDiscoveryScreen extends ConsumerStatefulWidget {
  const LiveDiscoveryScreen({super.key});

  @override
  ConsumerState<LiveDiscoveryScreen> createState() =>
      _LiveDiscoveryScreenState();
}

class _LiveDiscoveryScreenState extends ConsumerState<LiveDiscoveryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      ref.read(liveDiscoveryProvider.notifier).loadMore();
    }
  }

  void _startBroadcast() {
    final user = ref.read(authProvider).user;
    final kycStatus = user?.kycStatus.toLowerCase() ?? 'unsubmitted';
    if (kycStatus != 'verified' && kycStatus != 'approved') {
      showKycRequiredLiveModal(context);
    } else {
      GoLiveSetupDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(liveDiscoveryProvider);

    return Scaffold(
      backgroundColor: DesignTokens.bgOf(isDark),
      appBar: AppBar(
        backgroundColor: DesignTokens.bgOf(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: DesignTokens.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Live Now',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(liveDiscoveryProvider.notifier).refresh(),
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(liveDiscoveryProvider.notifier).refresh(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(LiveDiscoveryState state) {
    if (state.loading && state.streams.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.streams.isEmpty) {
      return _CenteredMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load live streams',
        message: state.error!,
        actionLabel: 'Try again',
        onAction: () => ref.read(liveDiscoveryProvider.notifier).refresh(),
      );
    }

    if (state.streams.isEmpty) {
      return _CenteredMessage(
        icon: Icons.videocam_off_rounded,
        title: 'Nobody is live right now',
        message: 'Be the first to go live and share the moment.',
        actionLabel: 'Go Live',
        onAction: _startBroadcast,
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final stream = state.streams[i];
              return LiveStreamCard(
                stream: stream,
                onTap: () => openLiveStream(ctx, stream.trackingId),
              );
            }, childCount: state.streams.length),
          ),
        ),
        SliverToBoxAdapter(
          child: state.loadingMore
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: 24),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 56,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
