import 'package:mobile/core/roles.dart';

/// Role-based feature access control for mobile app
class RoleFeatures {
  /// Features available for each role
  static const memberFeatures = {
    'community': true,
    'events': true,
    'audio_rooms': true,
    'stories': true,
    'feed': true,
    'content_studio': false,
    'link_in_bio': false,
    'courses': false,
    'coaching': false,
    'media_kit': false,
    'brand_deals': false,
    'physical_products': false,
    'digital_products': false,
    'inventory': false,
    'storefront': false,
    'orders': false,
    'shipping': false,
    'subscriptions': false,
    'memberships': false,
    'email_broadcasts': false,
    'email_sequences': false,
    'analytics': false,
    'inbox': true,
    'messages': true,
    'community_chat': true,
    'wallet': true,
    'payouts': false,
    'escrow': false,
    'gifts': true,
    'kyc': false,
  };

  static const creatorFeatures = {
    'community': true,
    'events': true,
    'audio_rooms': true,
    'stories': true,
    'feed': true,
    'content_studio': true,
    'link_in_bio': true,
    'courses': true,
    'coaching': true,
    'media_kit': true,
    'brand_deals': true,
    'physical_products': false, // NO E-COMMERCE FOR CREATORS
    'digital_products': false,
    'inventory': false,
    'storefront': false,
    'orders': false,
    'shipping': false,
    'subscriptions': false,
    'memberships': true, // Creators can sell community memberships
    'email_broadcasts': true,
    'email_sequences': true,
    'analytics': true,
    'inbox': true,
    'messages': true,
    'community_chat': true,
    'wallet': true,
    'payouts': true,
    'escrow': true,
    'gifts': true,
    'kyc': true,
  };

  static const vendorFeatures = {
    'community': true,
    'events': false,
    'audio_rooms': false,
    'stories': false,
    'feed': false,
    'content_studio': false,
    'link_in_bio': false,
    'courses': true, // Can sell courses
    'coaching': false,
    'media_kit': false,
    'brand_deals': false,
    'physical_products': true, // VENDOR ONLY
    'digital_products': true,
    'inventory': true,
    'storefront': true,
    'orders': true,
    'shipping': true,
    'subscriptions': false,
    'memberships': false,
    'email_broadcasts': true,
    'email_sequences': true,
    'analytics': true,
    'inbox': true,
    'messages': true,
    'community_chat': true,
    'wallet': true,
    'payouts': true,
    'escrow': true,
    'gifts': false,
    'kyc': true,
  };

  static const adminFeatures = {
    'community': false,
    'events': false,
    'audio_rooms': false,
    'stories': false,
    'feed': false,
    'content_studio': false,
    'link_in_bio': false,
    'courses': false,
    'coaching': false,
    'media_kit': false,
    'brand_deals': false,
    'physical_products': false,
    'digital_products': false,
    'inventory': false,
    'storefront': false,
    'orders': false,
    'shipping': false,
    'subscriptions': false,
    'memberships': false,
    'email_broadcasts': false,
    'email_sequences': false,
    'analytics': false,
    'inbox': false,
    'messages': false,
    'community_chat': false,
    'wallet': false,
    'payouts': false,
    'escrow': false,
    'gifts': false,
    'kyc': false,
  };

  /// Get feature access map for a role
  static Map<String, bool> getFeaturesForRole(UserRole role) {
    return switch (role) {
      UserRole.member => memberFeatures,
      UserRole.creator => creatorFeatures,
      UserRole.vendor => vendorFeatures,
      UserRole.admin => adminFeatures,
    };
  }

  /// Check if a role can access a specific feature
  static bool canAccess(UserRole role, String feature) {
    return getFeaturesForRole(role)[feature] ?? false;
  }

  /// Get list of accessible features for a role
  static List<String> getAccessibleFeatures(UserRole role) {
    final features = getFeaturesForRole(role);
    return features.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }
}
