import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../providers/live_discovery_provider.dart';
import 'live_stream_card.dart';

/// Public entry point for a broadcast: the `/live/:trackingId` deep-link page
/// resolves the stream server-side and drops the viewer into the room.
void openLiveStream(BuildContext context, String trackingId) {
  if (trackingId.isEmpty) return;
  context.push('/live/$trackingId');
}

/// Horizontal "Live Now" rail shown above the home feed. Hidden entirely when
/// nobody is broadcasting so the feed stays uncluttered; a skeleton shows while
/// the first page loads.
class LiveNowRail extends ConsumerStatefulWidget {
  const LiveNowRail({super.key});

  static const double _cardWidth = 156;
  static const double _cardHeight = 208;

  /// How often an on-screen rail re-reads page one so a broadcast that ended on
  /// another device (or was abandoned) stops being advertised without the user
  /// having to pull to refresh.
  static const Duration _pollInterval = Duration(seconds: 60);

  @override
  ConsumerState<LiveNowRail> createState() => _LiveNowRailState();
}

class _LiveNowRailState extends ConsumerState<LiveNowRail>
    with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(LiveNowRail._pollInterval, (_) {
      if (!mounted) return;
      ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the background after a while is exactly when the cached
    // list is most likely to be stale.
    if (state == AppLifecycleState.resumed) {
      ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(liveDiscoveryProvider);

    // Nothing live and finished loading: keep the feed clean, but surface a
    // retry when the fetch actually failed (the provider is kept alive for the
    // session, so it would otherwise stall empty forever).
    if (!state.loading && state.streams.isEmpty) {
      if (state.error != null) {
        return _RailError(
          onRetry: () => ref.read(liveDiscoveryProvider.notifier).refresh(),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/app/live-now'),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: LiveNowRail._cardHeight,
          child: state.loading
              ? const _RailSkeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.streams.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final stream = state.streams[i];
                    return SizedBox(
                      width: LiveNowRail._cardWidth,
                      child: LiveStreamCard(
                        stream: stream,
                        onTap: () => openLiveStream(ctx, stream.trackingId),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RailError extends StatelessWidget {
  const _RailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't load live streams.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) => Container(
        width: LiveNowRail._cardWidth,
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : DesignTokens.lightBorder,
          borderRadius: BorderRadius.circular(DesignTokens.rLg),
        ),
      ),
    );
  }
}
