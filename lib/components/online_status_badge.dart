import 'package:flutter/material.dart';
import '../core/design_tokens.dart';

/// Reusable Telegram-style Presence & Online Status Indicator Badge.
class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final String? lastSeen;
  final bool showLabel;
  final double dotSize;

  const OnlineStatusBadge({
    super.key,
    this.isOnline = true,
    this.lastSeen,
    this.showLabel = true,
    this.dotSize = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = DesignTokens.success; // Color(0xFF34C759)
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final textSecondary = isDark ? DesignTokens.darkTextSecondary : DesignTokens.lightTextSecondary;

    final labelText = isOnline ? 'online' : (lastSeen ?? 'last seen recently');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isOnline ? activeColor : inactiveColor,
            shape: BoxShape.circle,
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            labelText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isOnline ? FontWeight.w700 : FontWeight.w500,
              color: isOnline ? activeColor : textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Avatar wrapper displaying an online indicator green dot on the bottom right corner.
class OnlineAvatarBadge extends StatelessWidget {
  final Widget child;
  final bool isOnline;
  final double badgeSize;
  final double borderWidth;

  const OnlineAvatarBadge({
    super.key,
    required this.child,
    this.isOnline = true,
    this.badgeSize = 12.0,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
    final activeColor = DesignTokens.success; // Color(0xFF34C759)

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                border: Border.all(color: bg, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
