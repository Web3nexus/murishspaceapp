import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A particle used in the dust disintegration animation.
class _DustParticle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double spin;
  final double delay;
  final double lifespan;
  final Color color;
  final bool isDiamond;
  final double phase;

  _DustParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.delay,
    required this.lifespan,
    required this.color,
    required this.isDiamond,
    required this.phase,
  });
}

/// Custom painter that renders swirling dust/ash particles blowing away.
class _DustParticlePainter extends CustomPainter {
  final List<_DustParticle> particles;
  final double progress; // 0.0 -> 1.0

  _DustParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0 || particles.isEmpty) return;

    final paint = Paint()..isAntiAlias = true;

    for (final p in particles) {
      if (progress < p.delay) continue;

      final localProgress = ((progress - p.delay) / p.lifespan).clamp(0.0, 1.0);
      if (localProgress >= 1.0) continue;

      // Particle physics: upward drift with wind wobble and gentle deceleration
      final easedT = math.pow(localProgress, 0.75).toDouble();
      final wind = math.sin(localProgress * 7.0 + p.phase) * 14.0 * localProgress;
      final px = p.x + p.vx * easedT + wind;
      final py = p.y + p.vy * easedT;

      // Alpha fade out (visible at start, dissolves to 0 towards end of lifespan)
      final alpha = math.sin(localProgress * math.pi * 0.5 + math.pi * 0.5) *
          (1.0 - localProgress);
      if (alpha <= 0.01) continue;

      final currentSize = p.size * (1.0 - localProgress * 0.45);
      paint.color = p.color.withValues(alpha: (alpha * 0.9).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.spin * localProgress);

      if (p.isDiamond) {
        final path = Path()
          ..moveTo(0, -currentSize)
          ..lineTo(currentSize * 0.8, 0)
          ..lineTo(0, currentSize)
          ..lineTo(-currentSize * 0.8, 0)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset.zero, currentSize, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DustParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// A wrapper widget that provides a cinematic "dust / disintegration" effect
/// (like dissolving into ash and blowing away in the wind) when an item is deleted.
///
/// Can be triggered declaratively via [isDisintegrating], or programmatically
/// by using a [GlobalKey<DustEffectItemState>] and calling [disintegrate].
class DustEffectItem extends StatefulWidget {
  final Widget child;

  /// When set to `true`, the disintegration animation starts automatically.
  final bool isDisintegrating;

  /// Callback invoked when the dust animation finishes and the item has collapsed.
  final VoidCallback? onDisintegrated;

  /// Total duration of the disintegration sequence (dust drift + list collapse).
  final Duration duration;

  /// Optional primary tint color for a portion of the ash flecks (e.g. bubble color).
  final Color? particleColor;

  /// Whether to smoothly collapse the item's height/width after it turns to dust.
  final bool collapseOnFinish;

  /// Whether to trigger light haptic feedback at the start of disintegration.
  final bool enableHaptics;

  const DustEffectItem({
    super.key,
    required this.child,
    this.isDisintegrating = false,
    this.onDisintegrated,
    this.duration = const Duration(milliseconds: 750),
    this.particleColor,
    this.collapseOnFinish = true,
    this.enableHaptics = true,
  });

  @override
  State<DustEffectItem> createState() => DustEffectItemState();
}

class DustEffectItemState extends State<DustEffectItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_DustParticle>? _particles;
  Size _lastSize = Size.zero;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDisintegrated?.call();
      }
    });

    if (widget.isDisintegrating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startDisintegration());
    }
  }

  @override
  void didUpdateWidget(covariant DustEffectItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDisintegrating && !oldWidget.isDisintegrating && !_hasStarted) {
      _startDisintegration();
    } else if (!widget.isDisintegrating && oldWidget.isDisintegrating && _hasStarted) {
      _hasStarted = false;
      _particles = null;
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Programmatically trigger the dust disintegration animation.
  void disintegrate({VoidCallback? onComplete}) {
    if (_hasStarted) return;
    if (onComplete != null) {
      late final AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.completed) {
          _controller.removeStatusListener(listener);
          onComplete();
        }
      };
      _controller.addStatusListener(listener);
    }
    _startDisintegration();
  }

  void _startDisintegration() {
    if (_hasStarted || !mounted) return;
    _hasStarted = true;

    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _lastSize = box.size;
    }

    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }

    _generateParticles();
    _controller.forward(from: 0.0);
  }

  void _generateParticles() {
    final w = _lastSize.width > 20 ? _lastSize.width : 280.0;
    final h = _lastSize.height > 20 ? _lastSize.height : 60.0;

    final rand = math.Random();
    // Generate an organic density of particles proportional to the widget size
    final count = ((w * h) / 190).clamp(55, 130).toInt();

    final customTint = widget.particleColor ?? const Color(0xFF3B82F6);
    final ashPalette = [
      const Color(0xFF94A3B8), // slate 400
      const Color(0xFFCBD5E1), // slate 300
      const Color(0xFF64748B), // slate 500
      const Color(0xFF475569), // slate 600
      const Color(0xFF334155), // charcoal
      const Color(0xFFF59E0B), // ember gold
      const Color(0xFFFDE68A), // ember pale
      Colors.white.withValues(alpha: 0.9),
      customTint,
      customTint.withValues(alpha: 0.7),
    ];

    final list = <_DustParticle>[];
    for (int i = 0; i < count; i++) {
      // Natural distribution: slight bottom-to-top gradient
      final py = rand.nextDouble() * h;
      final px = rand.nextDouble() * w;

      // Particles at the top peel off first or randomized
      final delay = (1.0 - (py / h)) * 0.22 + rand.nextDouble() * 0.16;

      list.add(
        _DustParticle(
          x: px,
          y: py,
          vx: (rand.nextDouble() - 0.45) * 110.0, // slight rightward wind drift
          vy: -50.0 - rand.nextDouble() * 190.0, // strong upward lift
          size: 1.3 + rand.nextDouble() * 2.8,
          rotation: rand.nextDouble() * math.pi * 2,
          spin: (rand.nextDouble() - 0.5) * 8.0,
          delay: delay.clamp(0.0, 0.38),
          lifespan: 0.55 + rand.nextDouble() * 0.40,
          color: ashPalette[rand.nextInt(ashPalette.length)],
          isDiamond: rand.nextDouble() > 0.65,
          phase: rand.nextDouble() * math.pi * 2,
        ),
      );
    }

    _particles = list;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // 1. Child Dissolve:
        // First 35% of duration: subtle structural jitter + quick opacity fade to 0
        final childOpacity = t <= 0.0
            ? 1.0
            : (1.0 - (t / 0.38)).clamp(0.0, 1.0);

        final jitter = (t > 0.0 && t < 0.35)
            ? math.sin(t * 70.0) * (1.0 - t * 2.5) * 2.0
            : 0.0;

        // 2. Collapse Transition:
        // From 40% to 100% of the timeline, collapse the size smoothly
        final collapseFactor = widget.collapseOnFinish
            ? (t < 0.40
                ? 1.0
                : Curves.easeInOutCubic.transform(
                    (1.0 - ((t - 0.40) / 0.60)).clamp(0.0, 1.0),
                  ))
            : 1.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Clipped child collapse
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: collapseFactor,
                child: Transform.translate(
                  offset: Offset(jitter, 0),
                  child: IgnorePointer(
                    ignoring: _hasStarted,
                    child: Opacity(
                      opacity: childOpacity,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),

            // Dust particle overlay (unclipped so particles can drift upwards freely)
            if (t > 0.0 && _particles != null)
              Positioned(
                left: 0,
                top: 0,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: _lastSize,
                      painter: _DustParticlePainter(
                        particles: _particles!,
                        progress: t,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

