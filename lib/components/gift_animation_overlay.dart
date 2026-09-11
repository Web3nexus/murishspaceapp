import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sound_service.dart';

/// Data payload required to render a high-impact celebration gift animation.
class GiftAnimationData {
  final String giftName;
  final String? iconUrl;
  final String iconEmoji;
  final int coinPrice;
  final String? senderName;
  final String? recipientName;
  final String animationType; // 'micro', 'standard', 'premium', 'full_screen'

  const GiftAnimationData({
    required this.giftName,
    this.iconUrl,
    this.iconEmoji = '🎁',
    required this.coinPrice,
    this.senderName,
    this.recipientName,
    this.animationType = 'standard',
  });
}

/// State notifier managing the active gift animation overlay across the entire application.
class GiftAnimationNotifier extends Notifier<GiftAnimationData?> {
  Timer? _dismissTimer;

  @override
  GiftAnimationData? build() => null;

  void play(GiftAnimationData data) {
    _dismissTimer?.cancel();
    state = data;

    // Trigger celebratory haptic & audio
    HapticFeedback.heavyImpact();
    SoundService.instance.playNotificationPreview('chime');

    final durationMs = switch (data.animationType.toLowerCase()) {
      'full_screen' => 5200,
      'premium' => 4500,
      'micro' => 2600,
      _ => 3600,
    };

    _dismissTimer = Timer(Duration(milliseconds: durationMs), () {
      dismiss();
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }
}

final giftAnimationProvider = NotifierProvider<GiftAnimationNotifier, GiftAnimationData?>(
  GiftAnimationNotifier.new,
);

/// Root-level celebration overlay widget that reacts to [giftAnimationProvider].
/// Wraps application screens in [MaterialApp.builder].
class GiftAnimationOverlay extends ConsumerWidget {
  final Widget child;

  const GiftAnimationOverlay({super.key, required this.child});

  /// Static helper to trigger from anywhere with [WidgetRef].
  static void trigger(WidgetRef ref, GiftAnimationData data) {
    ref.read(giftAnimationProvider.notifier).play(data);
  }

  /// Static helper for contexts without a direct [WidgetRef] (falls back to OverlayEntry).
  static void show(
    BuildContext context, {
    required String giftName,
    String? iconUrl,
    String iconEmoji = '🎁',
    required int coinPrice,
    String? senderName,
    String? recipientName,
    String animationType = 'standard',
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    final data = GiftAnimationData(
      giftName: giftName,
      iconUrl: iconUrl,
      iconEmoji: iconEmoji,
      coinPrice: coinPrice,
      senderName: senderName,
      recipientName: recipientName,
      animationType: animationType,
    );

    entry = OverlayEntry(
      builder: (ctx) => _GiftOverlayView(
        data: data,
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(giftAnimationProvider);

    return Stack(
      children: [
        child,
        if (data != null)
          Positioned.fill(
            child: _GiftOverlayView(
              data: data,
              onDismiss: () => ref.read(giftAnimationProvider.notifier).dismiss(),
            ),
          ),
      ],
    );
  }
}

class _GiftOverlayView extends StatefulWidget {
  final GiftAnimationData data;
  final VoidCallback onDismiss;

  const _GiftOverlayView({
    required this.data,
    required this.onDismiss,
  });

  @override
  State<_GiftOverlayView> createState() => _GiftOverlayViewState();
}

class _GiftOverlayViewState extends State<_GiftOverlayView> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _auraCtrl;
  late final AnimationController _particleCtrl;

  late final List<_Particle> _particles;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    final isFullScreen = widget.data.animationType == 'full_screen';
    final isPremium = widget.data.animationType == 'premium' || isFullScreen;

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );

    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    final particleCount = isFullScreen ? 36 : (isPremium ? 26 : 16);
    _particles = List.generate(particleCount, (i) => _Particle.random(_rng));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _auraCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _entryCtrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = widget.data.animationType == 'full_screen';
    final isPremium = widget.data.animationType == 'premium' || isFullScreen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleDismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Darkened blur backdrop for premium & full_screen tiers
            if (isPremium)
              FadeTransition(
                opacity: _fadeAnim,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withOpacity(isFullScreen ? 0.65 : 0.45),
                  ),
                ),
              ),

            // Ambient background radial light rays
            FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.28),
                      const Color(0xFFFF2D55).withOpacity(0.18),
                      const Color(0xFFAF52DE).withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Floating celebration confetti / sparkles
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, _) {
                final progress = _particleCtrl.value;
                return Stack(
                  alignment: Alignment.center,
                  children: _particles.map((p) {
                    final t = (progress + p.phase) % 1.0;
                    final dx = p.xOffset + sin(t * pi * 2 + p.wobblePhase) * 35;
                    final dy = p.startY - (t * p.travelDistance);
                    final alpha = (sin(t * pi) * 255).clamp(0, 255).toInt();

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.rotate(
                        angle: t * pi * 2 * (p.isStar ? 1 : 0.5),
                        child: Opacity(
                          opacity: alpha / 255.0,
                          child: p.isStar
                              ? Icon(
                                  Icons.star_rounded,
                                  size: p.size,
                                  color: p.color,
                                )
                              : Container(
                                  width: p.size,
                                  height: p.size,
                                  decoration: BoxDecoration(
                                    color: p.color,
                                    shape: p.isCircle ? BoxShape.circle : BoxShape.rectangle,
                                    borderRadius: p.isCircle ? null : BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.color.withOpacity(0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            // Main Animated Gift Celebration Card
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Spinning Aura & Large Icon Card
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Spinning Rainbow / Gold Glow Ring
                            AnimatedBuilder(
                              animation: _auraCtrl,
                              builder: (context, _) {
                                return Transform.rotate(
                                  angle: _auraCtrl.value * 2 * pi,
                                  child: Container(
                                    width: 170,
                                    height: 170,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          const Color(0xFFFFD700).withOpacity(0.85),
                                          const Color(0xFFFF2D55).withOpacity(0.85),
                                          const Color(0xFFAF52DE).withOpacity(0.85),
                                          const Color(0xFF007AFF).withOpacity(0.85),
                                          const Color(0xFFFFD700).withOpacity(0.85),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF9500).withOpacity(0.6),
                                          blurRadius: 28,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Elevated Center Gift Pod
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222D),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                  width: 2.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: widget.data.iconUrl != null && widget.data.iconUrl!.isNotEmpty
                                    ? Image.network(
                                        widget.data.iconUrl!,
                                        width: 86,
                                        height: 86,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Text(
                                          widget.data.iconEmoji,
                                          style: const TextStyle(fontSize: 60),
                                        ),
                                      )
                                    : Text(
                                        widget.data.iconEmoji,
                                        style: const TextStyle(fontSize: 64),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Banner Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161A22).withOpacity(0.94),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFF9500).withOpacity(0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.data.senderName == 'You' ? 'GIFT SENT!' : 'GIFT RECEIVED!',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 14),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.data.senderName != null && widget.data.senderName!.isNotEmpty
                                    ? '${widget.data.senderName} sent ${widget.data.giftName}'
                                    : widget.data.giftName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (widget.data.recipientName != null && widget.data.recipientName!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'to ${widget.data.recipientName}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9500).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFFF9500).withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${widget.data.coinPrice} Coins',
                                      style: const TextStyle(
                                        color: Color(0xFFFFB340),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double xOffset;
  final double startY;
  final double travelDistance;
  final double size;
  final double phase;
  final double wobblePhase;
  final Color color;
  final bool isStar;
  final bool isCircle;

  _Particle({
    required this.xOffset,
    required this.startY,
    required this.travelDistance,
    required this.size,
    required this.phase,
    required this.wobblePhase,
    required this.color,
    required this.isStar,
    required this.isCircle,
  });

  factory _Particle.random(Random rng) {
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFFF9500), // Amber
      Color(0xFFFF2D55), // Pink
      Color(0xFFAF52DE), // Purple
      Color(0xFF00C7BE), // Cyan
      Color(0xFF34C759), // Emerald
    ];

    return _Particle(
      xOffset: (rng.nextDouble() - 0.5) * 340,
      startY: 120 + rng.nextDouble() * 100,
      travelDistance: 280 + rng.nextDouble() * 220,
      size: 7 + rng.nextDouble() * 11,
      phase: rng.nextDouble(),
      wobblePhase: rng.nextDouble() * pi * 2,
      color: colors[rng.nextInt(colors.length)],
      isStar: rng.nextBool(),
      isCircle: rng.nextBool(),
    );
  }
}
