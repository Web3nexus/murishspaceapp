import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';

/// MurihSpace brand asset paths organized by role
abstract final class BrandAssets {
  // Member role logos
  // (*-dark.png has dark/navy text for light backgrounds)
  // (*-light.png has white/light text for dark backgrounds)
  static const String memberLogoDark = 'assets/images/brand/member-logo-dark.png';
  static const String memberLogoLight = 'assets/images/brand/member-logo-light.png';
  static const String memberIconDark = 'assets/images/brand/member-icon-dark.png';
  static const String memberIconLight = 'assets/images/brand/member-icon-light.png';

  // Creator role logos
  static const String creatorLogoDark = 'assets/images/brand/creator-logo-dark.png';
  static const String creatorLogoLight = 'assets/images/brand/creator-logo-light.png';
  static const String creatorIconDark = 'assets/images/brand/creator-icon-dark.png';
  static const String creatorIconLight = 'assets/images/brand/creator-icon-light.png';

  // Vendor/Business role logos
  static const String vendorLogoDark = 'assets/images/brand/vendor-logo-dark.png';
  static const String vendorLogoLight = 'assets/images/brand/vendor-logo-light.png';
  static const String vendorIconDark = 'assets/images/brand/vendor-icon-dark.png';
  static const String vendorIconLight = 'assets/images/brand/vendor-icon-light.png';

  // Admin role logos
  static const String adminLogoDark = 'assets/images/brand/admin-logo-dark.png';
  static const String adminLogoLight = 'assets/images/brand/admin-logo-light.png';
  static const String adminIconDark = 'assets/images/brand/admin-icon-dark.png';
  static const String adminIconLight = 'assets/images/brand/admin-icon-light.png';

  // Fallback/Legacy assets (logo_white has dark text, logo_blue has light text)
  static const String logoDark = 'assets/images/brand/logo_white.png';
  static const String logoLight = 'assets/images/brand/logo_blue.png';
  static const String iconDark = 'assets/images/brand/icon_white.png';
  static const String iconLight = 'assets/images/brand/icon_blue.png';

  /// Get logo path for dark backgrounds (returns light/white logo)
  static String getLogoDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoLight,
      UserRole.vendor => vendorLogoLight,
      UserRole.admin => adminLogoLight,
      UserRole.member => memberLogoLight,
    };
  }

  /// Get logo path for light backgrounds (returns dark/navy logo)
  static String getLogoLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorLogoDark,
      UserRole.vendor => vendorLogoDark,
      UserRole.admin => adminLogoDark,
      UserRole.member => memberLogoDark,
    };
  }

  /// Get icon path for dark backgrounds (returns light/white icon)
  static String getIconDark(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconLight,
      UserRole.vendor => vendorIconLight,
      UserRole.admin => adminIconLight,
      UserRole.member => memberIconLight,
    };
  }

  /// Get icon path for light backgrounds (returns dark/navy icon)
  static String getIconLight(UserRole role) {
    return switch (role) {
      UserRole.creator => creatorIconDark,
      UserRole.vendor => vendorIconDark,
      UserRole.admin => adminIconDark,
      UserRole.member => memberIconDark,
    };
  }
}

/// The full horizontal MurihSpace logo wordmark. Picks the variant that matches
/// the current theme brightness (dark on light, white on dark).
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
          dark ? BrandAssets.logoLight : BrandAssets.logoDark,
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
          dark ? BrandAssets.iconLight : BrandAssets.iconDark,
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
  final Color? color;

  const BrandFavicon({
    super.key,
    this.size = 24,
    this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final dark = isDark ?? themeDark;
    final defaultColor = color ?? (dark ? Colors.white : const Color(0xFF007AFF));

    // In Light Mode (dark == false), use blue icon or dark mark so it is visible against light backgrounds.
    // In Dark Mode (dark == true), use white icon or light mark.
    final asset = dark ? BrandAssets.iconDark : BrandAssets.iconLight;

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          dark ? BrandAssets.memberIconLight : BrandAssets.memberIconDark,
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: color,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.chat_bubble_rounded,
            size: size,
            color: defaultColor,
          ),
        );
      },
    );
  }
}
