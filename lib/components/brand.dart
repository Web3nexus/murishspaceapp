import 'package:flutter/material.dart';
import '../core/roles.dart';

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

  // Fallback/Legacy assets
  static const String logoBlue = 'assets/images/brand/logo_blue.png';
  static const String logoWhite = 'assets/images/brand/logo_white.png';
  static const String iconBlue = 'assets/images/brand/icon_blue.png';
  static const String iconWhite = 'assets/images/brand/icon_white.png';

  /// Get logo path for a specific role
  static String getLogoDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoWhite,
      UserRole.vendor => vendorLogoWhite,
      UserRole.admin => logoWhite, // Admin uses standard white logo
      UserRole.member => memberLogoWhite,
    };
  }

  /// Get logo path for a specific role (light variant)
  static String getLogoLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoBlue,
      UserRole.vendor => vendorLogoBlue,
      UserRole.admin => logoBlue, // Admin uses standard blue logo
      UserRole.member => memberLogoBlue,
    };
  }

  /// Get icon path for a specific role
  static String getIconDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconWhite,
      UserRole.vendor => vendorIconWhite,
      UserRole.admin => iconWhite,
      UserRole.member => memberIconWhite,
    };
  }

  /// Get icon path for a specific role (light variant)
  static String getIconLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconBlue,
      UserRole.vendor => vendorIconBlue,
      UserRole.admin => iconBlue,
      UserRole.member => memberIconBlue,
    };
  }
}

/// The full horizontal MurihSpace logo wordmark. Picks the variant that matches
/// the current theme brightness (blue on light, white on dark).
/// Optionally respects a specific user role for role-specific branding.
class BrandLogo extends StatelessWidget {
  final double height;
  final bool isDark;
  final UserRole? role;

  const BrandLogo({
    super.key,
    this.height = 28,
    this.isDark = false,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final activeRole = role ?? UserRole.member;
    final asset = dark
        ? BrandAssets.getLogoDark(activeRole)
        : BrandAssets.getLogoLight(activeRole);

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
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
/// Optionally respects a specific user role for role-specific branding.
class BrandIcon extends StatelessWidget {
  final double size;
  final bool isDark;
  final UserRole? role;

  const BrandIcon({
    super.key,
    this.size = 48,
    this.isDark = false,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final activeRole = role ?? UserRole.member;
    final asset = dark
        ? BrandAssets.getIconDark(activeRole)
        : BrandAssets.getIconLight(activeRole);

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
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
