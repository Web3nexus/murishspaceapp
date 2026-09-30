import 'dart:ui';
import 'package:flutter/material.dart';

/// Realistic Liquid Glass container for modern, tactile UI.
/// Inspired by physical glass refraction, Blinn-Phong specular highlights,
/// Fresnel rim-lighting, and frosted depth blur.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Color? tintColor;
  final bool isDark;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.blurSigma = 18.0,
    this.tintColor,
    this.isDark = true,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark;
    final baseBgColor = effectiveDark
        ? const Color(0xFF0F141C).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.75);

    final borderColor = effectiveDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.55);

    final content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: effectiveDark ? 0.45 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (tintColor != null)
            BoxShadow(
              color: tintColor!.withValues(alpha: 0.08),
              blurRadius: 36,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: [
              // Liquid glass surface background & specular reflection gradient
              Container(
                decoration: BoxDecoration(
                  color: baseBgColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: borderColor, width: 1.2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: effectiveDark ? 0.15 : 0.45),
                      tintColor?.withValues(alpha: 0.04) ?? Colors.transparent,
                      Colors.white.withValues(alpha: effectiveDark ? 0.02 : 0.10),
                    ],
                  ),
                ),
              ),

              // Specular top rim sheen (simulating glass biconvex bevel light catch)
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: 1.2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: effectiveDark ? 0.40 : 0.80),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Inner content
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

/// Liquid glass badge or interactive pill.
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool isDark;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.tintColor,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.40),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
