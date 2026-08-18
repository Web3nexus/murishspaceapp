import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';

/// MurihSpace brand asset paths organized by role
abstract final class BrandAssets {
  // Member role logos
  static const String memberLogoBlue = 'assets/images/brand/member-logo-light.png';
  static const String memberLogoWhite = 'assets/images/brand/member-logo-dark.png';
  static const String memberIconBlue = 'assets/images/brand/member-icon-light.png';
  static const String memberIconWhite = 'assets/images/brand/member-icon-dark.png';

  // Creator role logos
  static const String creatorLogoBlue = 'assets/images/brand/creator-logo-light.png';
  static const String creatorLogoWhite = 'assets/images/brand/creator-logo-dark.png';
  static const String creatorIconBlue = 'assets/images/brand/creator-icon-light.png';
  static const String creatorIconWhite = 'assets/images/brand/creator-icon-dark.png';

  // Vendor/Business role logos
  static const String vendorLogoBlue = 'assets/images/brand/vendor-logo-light.png';
  static const String vendorLogoWhite = 'assets/images/brand/vendor-logo-dark.png';
  static const String vendorIconBlue = 'assets/images/brand/vendor-icon-light.png';
  static const String vendorIconWhite = 'assets/images/brand/vendor-icon-dark.png';

  // Admin role logos
  static const String adminLogoBlue = 'assets/images/brand/admin-logo-light.png';
  static const String adminLogoWhite = 'assets/images/brand/admin-logo-dark.png';
  static const String adminIconBlue = 'assets/images/brand/admin-icon-light.png';
  static const String adminIconWhite = 'assets/images/brand/admin-icon-dark.png';

  // Fallback/Legacy assets
  static const String logoBlue = 'assets/images/brand/logo_blue.png';
  static const String logoWhite = 'assets/images/brand/logo_white.png';
  static const String iconBlue = 'assets/images/brand/icon_blue.png';
  static const String iconWhite = 'assets/images/brand/icon_white.png';

  /// Get logo path for a specific role (dark variant)
  static String getLogoDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoWhite,
      UserRole.vendor => vendorLogoWhite,
      UserRole.admin => adminLogoWhite,
      UserRole.member => memberLogoWhite,
    };
  }

  /// Get logo path for a specific role (light variant)
  static String getLogoLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoBlue,
      UserRole.vendor => vendorLogoBlue,
      UserRole.admin => adminLogoBlue,
      UserRole.member => memberLogoBlue,
    };
  }

  /// Get icon path for a specific role (dark variant)
  static String getIconDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconWhite,
      UserRole.vendor => vendorIconWhite,
      UserRole.admin => adminIconWhite,
      UserRole.member => memberIconWhite,
    };
  }

  /// Get icon path for a specific role (light variant)
  static String getIconLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconBlue,
      UserRole.vendor => vendorIconBlue,
      UserRole.admin => adminIconBlue,
      UserRole.member => memberIconBlue,
    };
  }
}

/// The full horizontal MurihSpace logo wordmark. Picks the variant that matches
/// the current theme brightness (blue on light, white on dark).
/// Automatically auto-detects the logged-in user's role (creator, vendor, member, admin).
class BrandLogo extends ConsumerWidget {
  final double height;
  final bool? isDark;
  final UserRole? role;

  const BrandLogo({
    super.key,
    this.height = 28,
    this.isDark,
    this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final dark = isDark ?? themeDark;
    final activeRole = role ?? ref.watch(authProvider).user?.role ?? UserRole.member;
    final asset = dark
        ? BrandAssets.getLogoDark(activeRole)
        : BrandAssets.getLogoLight(activeRole);

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to standard logo if role-specific asset not found
        return Image.asset(
          dark ? BrandAssets.logoWhite : BrandAssets.logoBlue,
          height: height,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

/// The square MurihSpace brand mark (icon). Picks the variant for the theme.
/// Automatically auto-detects the logged-in user's role (creator, vendor, member, admin).
class BrandIcon extends ConsumerWidget {
  final double size;
  final bool? isDark;
  final UserRole? role;

  const BrandIcon({
    super.key,
    this.size = 48,
    this.isDark,
    this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final dark = isDark ?? themeDark;
    final activeRole = role ?? ref.watch(authProvider).user?.role ?? UserRole.member;
    final asset = dark
        ? BrandAssets.getIconDark(activeRole)
        : BrandAssets.getIconLight(activeRole);

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to standard icon if role-specific asset not found
        return Image.asset(
          dark ? BrandAssets.iconWhite : BrandAssets.iconBlue,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

/// The cropped MurihSpace favicon mark from splashlogo.png.
class BrandFavicon extends StatelessWidget {
  final double size;
  final bool? isDark;

  const BrandFavicon({
    super.key,
    this.size = 24,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final dark = isDark ?? themeDark;
    return Image.asset(
      dark ? BrandAssets.iconWhite : BrandAssets.iconBlue,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          dark ? BrandAssets.memberIconWhite : BrandAssets.memberIconBlue,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.chat_bubble_rounded,
            size: size,
            color: const Color(0xFF007AFF),
          ),
        );
      },
    );
  }
}
