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
