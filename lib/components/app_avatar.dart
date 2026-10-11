import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/design_tokens.dart';

/// shadcn-inspired Avatar for Flutter with active & inactive profile indicators.
///
/// Features:
/// - Subtle ring border matching shadcn avatar (`after:border after:border-border`)
/// - Cached image loading with smooth initials/fallback
/// - Status badge on bottom right with distinct active (green) and inactive (gray) states
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool? isOnline;
  final bool showStatus;
  final double badgeSize;
  final VoidCallback? onTap;
  final BoxShape shape;
  final double? borderRadius;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40.0,
    this.isOnline,
    this.showStatus = true,
    this.badgeSize = 10.0,
    this.onTap,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.borderColor,
  });

  String _getInitials() {
    if (name == null || name!.trim().isEmpty) return '';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
    final defaultBorder = isDark ? DesignTokens.darkBorder : DesignTokens.lightBorder;
    final borderCol = borderColor ?? defaultBorder.withValues(alpha: 0.6);

    final activeColor = DesignTokens.success; // Color(0xFF34C759)
    final inactiveColor = isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);

    final hasStatus = isOnline != null && showStatus;
    final statusColor = (isOnline ?? false) ? activeColor : inactiveColor;

    final resolvedRadius = shape == BoxShape.circle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(borderRadius ?? 8.0);

    Widget avatarCore = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : resolvedRadius,
        border: Border.all(color: borderCol, width: 1.0),
        color: isDark ? DesignTokens.darkSurfaceSecondary : DesignTokens.primarySoft,
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl!.trim(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildFallback(isDark),
                errorWidget: (context, url, error) => _buildFallback(isDark),
              )
            : _buildFallback(isDark),
      ),
    );

    if (onTap != null) {
      avatarCore = GestureDetector(
        onTap: onTap,
        child: avatarCore,
      );
    }

    if (!hasStatus) {
      return avatarCore;
    }

    // Status Badge overlay
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCore,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: surfaceBg, width: 1.5),
              boxShadow: (isOnline ?? false)
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback(bool isDark) {
    final initials = _getInitials();
    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: isDark ? DesignTokens.darkTextPrimary : DesignTokens.primaryDark,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person,
        size: size * 0.52,
        color: isDark ? DesignTokens.darkTextSecondary : DesignTokens.primaryDark,
      ),
    );
  }
}

