import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/live_models.dart';
import '../core/design_tokens.dart';
import '../providers/live_discovery_provider.dart';

/// Public entry point for a broadcast. If a full [LiveStream] instance is provided,
/// opens `/app/live` directly with complete room context so the user drops into
/// the stream immediately without a redundant HTTP resolution step.
/// If only a tracking ID / token is provided, opens `/live/:trackingId` to resolve.
void openLiveStream(BuildContext context, dynamic streamOrToken) {
  if (streamOrToken is LiveStream) {
    if (!streamOrToken.isLive || streamOrToken.status == 'ended') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This live stream has ended.')),
      );
      return;
    }
    final query = <String, String>{
      'streamId': streamOrToken.id.toString(),
      if (streamOrToken.trackingId.isNotEmpty)
        'trackingId': streamOrToken.trackingId,
      'title': streamOrToken.title.isNotEmpty
          ? streamOrToken.title
          : 'Live Broadcast',
      'hostName': streamOrToken.host?.name ?? 'Creator',
      'isHost': 'false',
      'streamMode': streamOrToken.streamMode,
      if (streamOrToken.host?.avatarUrl != null &&
          streamOrToken.host!.avatarUrl!.isNotEmpty)
        'hostAvatarUrl': streamOrToken.host!.avatarUrl!,
      if (streamOrToken.community?.name != null &&
          streamOrToken.community!.name.isNotEmpty)
        'communityName': streamOrToken.community!.name,
    };
    final uri = Uri(path: '/app/live', queryParameters: query);
    context.push(uri.toString());
    return;
  }

  final token = streamOrToken?.toString().trim() ?? '';
  if (token.isEmpty) return;
  context.push('/live/$token');
}

/// Horizontal "Live Now" rail shown above the home feed. Hidden entirely when
/// nobody is broadcasting so the feed stays uncluttered; a skeleton shows while
/// the first page loads.
class LiveNowRail extends ConsumerStatefulWidget {
  const LiveNowRail({super.key});

  static const double _bubbleWidth = 92;
  static const double _bubbleSize = 76;
  static const double _cardHeight = 136;

  /// How often an on-screen rail re-reads page one so a broadcast that ended
  /// without this device seeing it (host ended elsewhere, app killed) stops
  /// being advertised without the user having to pull to refresh.
  static const Duration _pollInterval = Duration(seconds: 30);

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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.streams.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final stream = state.streams[i];
                    return _LiveBubble(
                      key: ValueKey(stream.id),
                      stream: stream,
                      onTap: () => openLiveStream(ctx, stream),
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (ctx, i) => SizedBox(
        width: LiveNowRail._bubbleWidth,
        child: Column(
          children: [
            Container(
              width: LiveNowRail._bubbleSize,
              height: LiveNowRail._bubbleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? DesignTokens.darkSurface
                    : DesignTokens.lightBorder,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 10,
              decoration: BoxDecoration(
                color: isDark
                    ? DesignTokens.darkSurface
                    : DesignTokens.lightBorder,
                borderRadius: BorderRadius.circular(DesignTokens.rSm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One live broadcaster as a circle: the photo sits inside a spinning red-amber
/// ring, with a pulsing LIVE tag underneath. Tapping it presses in slightly, then opens the stream.
class _LiveBubble extends StatefulWidget {
  const _LiveBubble({super.key, required this.stream, required this.onTap});

  final LiveStream stream;
  final VoidCallback onTap;

  @override
  State<_LiveBubble> createState() => _LiveBubbleState();
}

class _LiveBubbleState extends State<_LiveBubble>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final host = widget.stream.host;
    final name = (host?.name.trim().isNotEmpty ?? false)
        ? host!.name
        : 'Creator';
    final avatarUrl = host?.avatarUrl;
    final size = LiveNowRail._bubbleSize;
    final photoSize = size - 8;

    // InkWell (not a bare GestureDetector) so keyboard focus can reach the bubble and activate it.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: LiveNowRail._bubbleWidth,
            child: Column(
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Ring: a sweep gradient rotating behind a disc that
                      // leaves only the outer edge visible.
                      RotationTransition(
                        turns: _spin,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                DesignTokens.danger,
                                DesignTokens.warning,
                                DesignTokens.danger,
                                DesignTokens.warning,
                                DesignTokens.danger,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: size - 4,
                        height: size - 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? DesignTokens.darkBg
                              : DesignTokens.lightSurface,
                        ),
                      ),
                      ClipOval(
                        child: SizedBox(
                          width: photoSize,
                          height: photoSize,
                          child: _Avatar(url: avatarUrl, name: name),
                        ),
                      ),
                      Positioned(bottom: -2, child: _LiveTag(pulse: _pulse)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${widget.stream.viewersCount} watching',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallback = Container(
      color: DesignTokens.primarySoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: DesignTokens.primary,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: 1.08,
      ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: DesignTokens.danger,
          borderRadius: BorderRadius.circular(DesignTokens.rPill),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
