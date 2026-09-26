import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
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
      'full_screen' => 5400,
      'premium' => 4800,
      'micro' => 3000,
      _ => 4000,
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
class GiftAnimationOverlay extends ConsumerWidget {
  final Widget child;

  const GiftAnimationOverlay({super.key, required this.child});

  static void trigger(WidgetRef ref, GiftAnimationData data) {
    ref.read(giftAnimationProvider.notifier).play(data);
  }

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

enum _GiftKind { lion, flower, rocket, diamond, crown, car, coins, standard }

_GiftKind _detectKind(String name, String emoji) {
  final s = '$name $emoji'.toLowerCase();
  if (s.contains('lion') || s.contains('anpu') || s.contains('🦁') || s.contains('roar')) {
    return _GiftKind.lion;
  }
  if (s.contains('rose') || s.contains('flower') || s.contains('petal') || s.contains('🌹') || s.contains('🌸') || s.contains('love') || s.contains('heart') || s.contains('💖')) {
    return _GiftKind.flower;
  }
  if (s.contains('rocket') || s.contains('cruise') || s.contains('🚀') || s.contains('space') || s.contains('blast')) {
    return _GiftKind.rocket;
  }
  if (s.contains('diamond') || s.contains('gem') || s.contains('ring') || s.contains('💎') || s.contains('master')) {
    return _GiftKind.diamond;
  }
  if (s.contains('crown') || s.contains('king') || s.contains('queen') || s.contains('royal') || s.contains('👑')) {
    return _GiftKind.crown;
  }
  if (s.contains('lambo') || s.contains('car') || s.contains('mansion') || s.contains('🏎️')) {
    return _GiftKind.car;
  }
  if (s.contains('coin') || s.contains('gold') || s.contains('money') || s.contains('cash') || s.contains('🪙') || s.contains('legit')) {
    return _GiftKind.coins;
  }
  return _GiftKind.standard;
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
  late final AnimationController _shakeCtrl;

  late final List<_Particle> _particles;
  late final List<_PetalParticle> _petals;
  late final _GiftKind _kind;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _kind = _detectKind(widget.data.giftName, widget.data.iconEmoji);
    final isFullScreen = widget.data.animationType == 'full_screen' || _kind == _GiftKind.lion;
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

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    final particleCount = isFullScreen ? 40 : (isPremium ? 28 : 16);
    _particles = List.generate(particleCount, (i) => _Particle.random(_rng, _kind));
    _petals = List.generate(36, (i) => _PetalParticle.random(_rng));

    _entryCtrl.forward();

    // Trigger Lion Roar effects: screen shake & haptic roar burst sequence
    if (_kind == _GiftKind.lion) {
      _shakeCtrl.forward();
      Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 350), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 600), () => HapticFeedback.mediumImpact());
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _auraCtrl.dispose();
    _particleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _entryCtrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = widget.data.animationType == 'full_screen' || _kind == _GiftKind.lion;
    final isPremium = widget.data.animationType == 'premium' || isFullScreen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleDismiss,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            // Apply camera shake if Lion Roar is active
            double shakeX = 0;
            double shakeY = 0;
            if (_kind == _GiftKind.lion && _shakeCtrl.isAnimating) {
              final t = 1.0 - _shakeCtrl.value;
              final mag = t * 14.0;
              shakeX = sin(_shakeCtrl.value * 28 * pi) * mag;
              shakeY = cos(_shakeCtrl.value * 24 * pi) * (mag * 0.7);
            }
            return Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Darkened blur backdrop for premium & full_screen tiers
              if (isPremium)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withValues(alpha: isFullScreen ? 0.72 : 0.50),
                    ),
                  ),
                ),

              // Ambient backdrop glow rays
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _getGlowColors(_kind),
                      stops: const [0.0, 0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // Lion sonic roar shockwave rings
              if (_kind == _GiftKind.lion)
                AnimatedBuilder(
                  animation: _auraCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(400, 400),
                      painter: _SonicRoarRingsPainter(progress: _auraCtrl.value),
                    );
                  },
                ),

              // Flower/Rose: cascading swirling 3D rose petals
              if (_kind == _GiftKind.flower)
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (context, _) {
                    final progress = _particleCtrl.value;
                    return Stack(
                      children: _petals.map((p) {
                        final t = (progress + p.phase) % 1.0;
                        final screenW = MediaQuery.of(context).size.width;
                        final screenH = MediaQuery.of(context).size.height;
                        final dx = p.xRatio * screenW + sin(t * pi * 3 + p.wobblePhase) * 45;
                        final dy = t * (screenH + 100) - 50;
                        final rotZ = t * pi * 4 + p.spinPhase;
                        final scaleX = cos(t * pi * 5 + p.wobblePhase).abs().clamp(0.25, 1.0);

                        return Positioned(
                          left: dx,
                          top: dy,
                          child: Transform.scale(
                            scaleX: scaleX,
                            scaleY: 1.0,
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle: rotZ,
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: (sin(t * pi) * 0.95).clamp(0.0, 1.0),
                                child: _PetalWidget(size: p.size, color: p.color),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

              // Confetti / sparkles / diamonds / coins particles
              if (_kind != _GiftKind.flower)
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (context, _) {
                    final progress = _particleCtrl.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: _particles.map((p) {
                        final t = (progress + p.phase) % 1.0;
                        final dx = p.xOffset + sin(t * pi * 2 + p.wobblePhase) * 40;
                        final dy = p.startY - (t * p.travelDistance);
                        final alpha = (sin(t * pi) * 255).clamp(0, 255).toInt();

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.rotate(
                            angle: t * pi * 2 * (p.isStar ? 1.5 : 0.8),
                            child: Opacity(
                              opacity: alpha / 255.0,
                              child: _buildParticleWidget(p, _kind),
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
                                      width: 176,
                                      height: 176,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: SweepGradient(
                                          colors: _getRingColors(_kind),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getPrimaryColor(_kind).withValues(alpha: 0.65),
                                            blurRadius: 32,
                                            spreadRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Elevated Center Gift Pod with real image
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181B24),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _getPrimaryColor(_kind),
                                    width: 3.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 24,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _buildGiftCenterArtwork(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Banner Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141822).withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getPrimaryColor(_kind).withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top Header Tag
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: _getPrimaryColor(_kind), size: 15),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getBannerTitle(_kind, widget.data.senderName),
                                      style: TextStyle(
                                        color: _getPrimaryColor(_kind),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.auto_awesome, color: _getPrimaryColor(_kind), size: 15),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.data.senderName != null && widget.data.senderName!.isNotEmpty
                                      ? '${widget.data.senderName} sent ${widget.data.giftName}'
                                      : widget.data.giftName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (widget.data.recipientName != null && widget.data.recipientName!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'to ${widget.data.recipientName}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🪙', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${widget.data.coinPrice} MSH',
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
      ),
    );
  }

  Widget _buildGiftCenterArtwork() {
    final rawUrl = widget.data.iconUrl;
    final resolvedUrl = ApiClient.resolveUrl(rawUrl);

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: 90,
        height: 90,
        fit: BoxFit.contain,
        placeholder: (_, _) => const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
        ),
        errorWidget: (_, _, _) => Text(
          widget.data.iconEmoji,
          style: const TextStyle(fontSize: 66),
        ),
      );
    }

    return Text(
      widget.data.iconEmoji,
      style: const TextStyle(fontSize: 66),
    );
  }

  String _getBannerTitle(_GiftKind kind, String? sender) {
    return switch (kind) {
      _GiftKind.lion => '🦁 MIGHTY LION ROAR!',
      _GiftKind.flower => '🌹 BLOOMING ROSE TRIBUTE!',
      _GiftKind.rocket => '🚀 SUPER ROCKET LAUNCH!',
      _GiftKind.diamond => '💎 SPARKLING DIAMOND GLAMOUR!',
      _GiftKind.crown => '👑 ROYAL CORONATION!',
      _GiftKind.car => '🏎️ TURBO SUPERCAR BOOST!',
      _GiftKind.coins => '🪙 GOLD COIN SHOWER!',
      _ => sender == 'You' ? 'GIFT SENT!' : 'GIFT RECEIVED!',
    };
  }

  List<Color> _getGlowColors(_GiftKind kind) {
    return switch (kind) {
      _GiftKind.lion => [
          const Color(0xFFFF9500).withValues(alpha: 0.40),
          const Color(0xFFFFD700).withValues(alpha: 0.25),
          const Color(0xFFFF3B30).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      _GiftKind.flower => [
          const Color(0xFFFF2D55).withValues(alpha: 0.42),
          const Color(0xFFFF3B30).withValues(alpha: 0.24),
          const Color(0xFFAF52DE).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      _GiftKind.rocket => [
          const Color(0xFFFF9500).withValues(alpha: 0.40),
          const Color(0xFFAF52DE).withValues(alpha: 0.25),
          const Color(0xFF007AFF).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      _GiftKind.diamond => [
          const Color(0xFF00C7BE).withValues(alpha: 0.40),
          const Color(0xFF007AFF).withValues(alpha: 0.28),
          const Color(0xFFE5E5EA).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      _GiftKind.crown => [
          const Color(0xFFFFD700).withValues(alpha: 0.45),
          const Color(0xFFFF9500).withValues(alpha: 0.25),
          const Color(0xFFAF52DE).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      _ => [
          const Color(0xFFFFD700).withValues(alpha: 0.28),
          const Color(0xFFFF2D55).withValues(alpha: 0.18),
          const Color(0xFFAF52DE).withValues(alpha: 0.10),
          Colors.transparent,
        ],
    };
  }

  List<Color> _getRingColors(_GiftKind kind) {
    return switch (kind) {
      _GiftKind.lion => [
          const Color(0xFFFF9500),
          const Color(0xFFFFD700),
          const Color(0xFFFF3B30),
          const Color(0xFFFF9500),
        ],
      _GiftKind.flower => [
          const Color(0xFFFF2D55),
          const Color(0xFFFF3B30),
          const Color(0xFFFF7597),
          const Color(0xFFFF2D55),
        ],
      _GiftKind.diamond => [
          const Color(0xFF00C7BE),
          const Color(0xFF007AFF),
          const Color(0xFFE5E5EA),
          const Color(0xFF00C7BE),
        ],
      _GiftKind.crown => [
          const Color(0xFFFFD700),
          const Color(0xFFFF9500),
          const Color(0xFFAF52DE),
          const Color(0xFFFFD700),
        ],
      _ => [
          const Color(0xFFFFD700),
          const Color(0xFFFF2D55),
          const Color(0xFFAF52DE),
          const Color(0xFF007AFF),
          const Color(0xFFFFD700),
        ],
    };
  }

  Color _getPrimaryColor(_GiftKind kind) {
    return switch (kind) {
      _GiftKind.lion => const Color(0xFFFF9500),
      _GiftKind.flower => const Color(0xFFFF2D55),
      _GiftKind.rocket => const Color(0xFFAF52DE),
      _GiftKind.diamond => const Color(0xFF00C7BE),
      _GiftKind.crown => const Color(0xFFFFD700),
      _GiftKind.car => const Color(0xFF34C759),
      _GiftKind.coins => const Color(0xFFFF9500),
      _ => const Color(0xFFFFD700),
    };
  }

  Widget _buildParticleWidget(_Particle p, _GiftKind kind) {
    if (kind == _GiftKind.coins) {
      return Container(
        width: p.size,
        height: p.size,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0xFFFF9500), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Text('🪙', style: TextStyle(fontSize: p.size * 0.75)),
        ),
      );
    }

    if (kind == _GiftKind.diamond) {
      return Icon(Icons.diamond_rounded, size: p.size, color: const Color(0xFF00E5FF));
    }

    if (p.isStar) {
      return Icon(Icons.star_rounded, size: p.size, color: p.color);
    }

    return Container(
      width: p.size,
      height: p.size,
      decoration: BoxDecoration(
        color: p.color,
        shape: p.isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: p.isCircle ? null : BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: p.color.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering concentric expanding acoustic shockwaves for the Lion roar.
class _SonicRoarRingsPainter extends CustomPainter {
  final double progress;

  const _SonicRoarRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final t = (progress + i * 0.25) % 1.0;
      final radius = 60.0 + t * 130.0;
      final alpha = ((1.0 - t) * 220).clamp(0, 255).toInt();
      paint.color = const Color(0xFFFFD700).withAlpha(alpha);
      paint.strokeWidth = (4.5 * (1.0 - t)).clamp(1.0, 4.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SonicRoarRingsPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Swirling 3D rose petal representation.
class _PetalParticle {
  final double xRatio;
  final double size;
  final double phase;
  final double wobblePhase;
  final double spinPhase;
  final Color color;

  _PetalParticle({
    required this.xRatio,
    required this.size,
    required this.phase,
    required this.wobblePhase,
    required this.spinPhase,
    required this.color,
  });

  factory _PetalParticle.random(Random rng) {
    const petalColors = [
      Color(0xFFE50914), // Deep velvet red
      Color(0xFFFF2D55), // Vibrant rose
      Color(0xFFC2185B), // Crimson
      Color(0xFFFF5252), // Scarlet
      Color(0xFFFF80AB), // Soft petal pink
    ];

    return _PetalParticle(
      xRatio: rng.nextDouble(),
      size: 14 + rng.nextDouble() * 18,
      phase: rng.nextDouble(),
      wobblePhase: rng.nextDouble() * pi * 2,
      spinPhase: rng.nextDouble() * pi * 2,
      color: petalColors[rng.nextInt(petalColors.length)],
    );
  }
}

class _PetalWidget extends StatelessWidget {
  final double size;
  final Color color;

  const _PetalWidget({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.35,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.9),
          topRight: Radius.circular(size * 0.4),
          bottomLeft: Radius.circular(size * 0.4),
          bottomRight: Radius.circular(size * 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

  factory _Particle.random(Random rng, _GiftKind kind) {
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFFF9500), // Amber
      Color(0xFFFF2D55), // Pink
      Color(0xFFAF52DE), // Purple
      Color(0xFF00C7BE), // Cyan
      Color(0xFF34C759), // Emerald
    ];

    return _Particle(
      xOffset: (rng.nextDouble() - 0.5) * 360,
      startY: 130 + rng.nextDouble() * 100,
      travelDistance: 300 + rng.nextDouble() * 240,
      size: 7 + rng.nextDouble() * 12,
      phase: rng.nextDouble(),
      wobblePhase: rng.nextDouble() * pi * 2,
      color: colors[rng.nextInt(colors.length)],
      isStar: rng.nextBool(),
      isCircle: rng.nextBool(),
    );
  }
}
