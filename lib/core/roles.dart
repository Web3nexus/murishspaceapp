/// Platform role model shared across navigation and auth.
enum UserRole {
  member,
  creator,
  vendor,
  admin;

  static UserRole fromApi(String role) {
    switch (role) {
      case 'creator':
        return UserRole.creator;
      case 'vendor':
        return UserRole.vendor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.member;
    }
  }

  String get apiValue => switch (this) {
        UserRole.member => 'member',
        UserRole.creator => 'creator',
        UserRole.vendor => 'vendor',
        UserRole.admin => 'admin',
      };

  String get label => switch (this) {
        UserRole.member => 'Member',
        UserRole.creator => 'Creator',
        UserRole.vendor => 'Vendor',
        UserRole.admin => 'Admin',
      };

  /// Roles that can sell products.
  bool get isSeller =>
      this == UserRole.creator || this == UserRole.vendor || this == UserRole.admin;
}

/// Centralized permission registry mirroring the backend
/// `App\Services\PermissionService` map. Keep in sync with the backend so the
/// mobile client never grants an action the API would deny.
///
/// The backend `admin` role bypasses all checks; mirror that here via [UserRole.admin].
abstract final class Permissions {
  /// Permission key → roles that hold it. Admin always holds all permissions.
  static const Map<String, List<UserRole>> _map = {
    // Storefront
    'storefront.view': [UserRole.creator, UserRole.vendor],
    'storefront.manage': [UserRole.creator, UserRole.vendor],

    // Products
    'product.create': [UserRole.creator, UserRole.vendor],
    'product.manage': [UserRole.creator, UserRole.vendor],

    // Community
    'community.create': [UserRole.creator],
    'community.manage': [UserRole.creator],

    // Events
    'event.create': [UserRole.creator],
    'event.manage': [UserRole.creator],

    // Conferencing
    'conference.host': [UserRole.creator],
    'conference.join': [UserRole.member, UserRole.creator, UserRole.vendor],

    // Live sessions
    'live.host': [UserRole.creator],

    // Gifts
    'gift.send': [UserRole.member, UserRole.creator, UserRole.vendor],
    'gift.receive': [UserRole.creator],

    // Wallet
    'wallet.deposit': [UserRole.member, UserRole.creator, UserRole.vendor],
    'wallet.transfer': [UserRole.creator, UserRole.vendor],
    'wallet.withdraw': [UserRole.creator, UserRole.vendor],

    // Analytics
    'creator.analytics.view': [UserRole.creator],
    'vendor.analytics.view': [UserRole.vendor],

    // Link-in-bio
    'link_in_bio.manage': [UserRole.creator],

    // AI onboarding
    'ai_onboarding.access': [UserRole.creator, UserRole.vendor],

    // Verification
    'verification.apply': [UserRole.member, UserRole.creator, UserRole.vendor],

    // Role upgrades
    'role.upgrade.apply': [UserRole.member, UserRole.creator, UserRole.vendor],
    'role.upgrade.review': [UserRole.admin],

    // Courses & coaching
    'course.create': [UserRole.creator],
    'coaching.offer': [UserRole.creator],

    // Memberships (selling)
    'membership.create': [UserRole.creator],

    // Brand deals & marketing
    'brand_deal.manage': [UserRole.creator],
    'marketing.manage': [UserRole.creator],

    // Media kit
    'media_kit.manage': [UserRole.creator],

    // Payouts
    'payout.request': [UserRole.creator, UserRole.vendor],
  };

  /// Whether a role holds a given permission (admins bypass all checks).
  static bool roleHas(UserRole role, String permission) {
    if (role == UserRole.admin) return true;
    return _map[permission]?.contains(role) ?? false;
  }

  /// All permission keys granted to a role (admin → every key).
  static Set<String> permissionsFor(UserRole role) {
    if (role == UserRole.admin) return _map.keys.toSet();
    return _map.entries
        .where((e) => e.value.contains(role))
        .map((e) => e.key)
        .toSet();
  }

  /// Whether a role holds at least one of the given permissions (admin bypasses).
  static bool roleHasAny(UserRole role, List<String> permissions) =>
      permissions.any((p) => roleHas(role, p));
}
