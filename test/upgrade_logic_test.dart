import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';
import 'package:mobile/providers/kyc_provider.dart';
import 'package:mobile/providers/role_provider.dart';
import 'package:mobile/providers/wallet_provider.dart';

void main() {
  group('Permissions (mirror of PermissionService)', () {
    test('admin bypasses every check', () {
      for (final p in [
        'role.upgrade.review',
        'storefront.manage',
        'community.create',
        'live.host',
      ]) {
        expect(Permissions.roleHas(UserRole.admin, p), isTrue,
            reason: 'admin should hold $p');
      }
    });

    test('member has consumer permissions only', () {
      expect(Permissions.roleHas(UserRole.member, 'gift.send'), isTrue);
      expect(Permissions.roleHas(UserRole.member, 'verification.apply'), isTrue);
      expect(Permissions.roleHas(UserRole.member, 'wallet.deposit'), isTrue);
      expect(Permissions.roleHas(UserRole.member, 'role.upgrade.apply'), isTrue);

      expect(Permissions.roleHas(UserRole.member, 'live.host'), isFalse);
      expect(Permissions.roleHas(UserRole.member, 'community.create'), isFalse);
      expect(Permissions.roleHas(UserRole.member, 'product.create'), isFalse);
      expect(Permissions.roleHas(UserRole.member, 'wallet.withdraw'), isFalse);
    });

    test('creator upgrades to selling permissions', () {
      expect(Permissions.roleHas(UserRole.creator, 'live.host'), isTrue);
      expect(Permissions.roleHas(UserRole.creator, 'community.create'), isTrue);
      expect(Permissions.roleHas(UserRole.creator, 'product.create'), isTrue);
      expect(Permissions.roleHas(UserRole.creator, 'storefront.manage'), isTrue);
      expect(Permissions.roleHas(UserRole.creator, 'link_in_bio.manage'), isTrue);
      expect(Permissions.roleHas(UserRole.creator, 'ai_onboarding.access'), isTrue);

      expect(Permissions.roleHas(UserRole.creator, 'vendor.analytics.view'), isFalse);
    });

    test('vendor has business permissions but not creator-only ones', () {
      expect(Permissions.roleHas(UserRole.vendor, 'product.create'), isTrue);
      expect(Permissions.roleHas(UserRole.vendor, 'payout.request'), isTrue);
      expect(Permissions.roleHas(UserRole.vendor, 'ai_onboarding.access'), isTrue);

      expect(Permissions.roleHas(UserRole.vendor, 'live.host'), isFalse);
      expect(Permissions.roleHas(UserRole.vendor, 'community.create'), isFalse);
      expect(Permissions.roleHas(UserRole.vendor, 'link_in_bio.manage'), isFalse);
    });

    test('roleHasAny is true when any permission is held', () {
      expect(
        Permissions.roleHasAny(
          UserRole.member,
          ['live.host', 'community.create', 'gift.send'],
        ),
        isTrue,
      );
      expect(
        Permissions.roleHasAny(UserRole.vendor, ['live.host', 'community.create']),
        isFalse,
      );
    });

    test('unknown permission resolves to false', () {
      expect(Permissions.roleHas(UserRole.creator, 'does.not.exist'), isFalse);
      expect(Permissions.permissionsFor(UserRole.admin), contains('role.upgrade.review'));
    });
  });

  group('Wallet (Sprint 9 multi-wallet contract)', () {
    test('parses a system wallet from the list payload', () {
      final wallet = Wallet.fromJson({
        'id': 3,
        'wallet_type': 'system',
        'available': 5000,
        'pending': 200,
        'reserved': 0,
        'escrow': 0,
        'withdrawable': 5000,
        'non_withdrawable': 200,
        'disputed': 0,
        'total': 5200,
        'currency': 'NGN',
        'has_pin': true,
        'status': 'active',
      });

      expect(wallet.type, WalletType.system);
      expect(wallet.available, 5000);
      expect(wallet.currency, 'NGN');
      expect(wallet.hasPin, isTrue);
    });

    test('defaults gracefully for sparse payloads', () {
      final wallet = Wallet.fromJson(const {'wallet_type': 'creator'});
      expect(wallet.type, WalletType.creator);
      expect(wallet.available, 0);
      expect(wallet.currency, 'NGN');
      expect(wallet.hasPin, isFalse);
    });

    test('unknown wallet types fall back to system', () {
      final wallet = Wallet.fromJson(const {'wallet_type': 'mystery'});
      expect(wallet.type, WalletType.system);
    });

    test('formatted renders currency symbol', () {
      final wallet = Wallet.fromJson({
        'wallet_type': 'system',
        'available': 125000,
        'currency': 'NGN',
      });
      expect(wallet.formatted, '₦1250.00');
    });

    test('FeePreview reads net_amount from the backend payload', () {
      final preview = FeePreview.fromJson(const {
        'gross_amount': 100000,
        'platform_fee': 1500,
        'processing_fee': 0,
        'total_fee': 1500,
        'net_amount': 98500,
        'total_charged': 100000,
        'currency': 'NGN',
      });
      expect(preview.platformFee, 1500);
      expect(preview.recipientAmount, 98500);
      expect(preview.totalCharged, 100000);
    });
  });

  group('KycStatusInfo (Sprint 2 logic)', () {
    test('parses verified status and providers', () {
      final status = KycStatusInfo.fromJson({
        'kyc_status': 'verified',
        'kyc_provider': 'smile_identity',
        'verification_id': 42,
        'providers': ['smile_identity', 'seerbit'],
        'provider_enabled': true,
      });
      expect(status.isVerified, isTrue);
      expect(status.isPending, isFalse);
      expect(status.provider, 'smile_identity');
      expect(status.verificationId, 42);
      expect(status.providers, hasLength(2));
      expect(status.providerEnabled, isTrue);
    });

    test('isVerified reflects approved too', () {
      expect(KycStatusInfo.fromJson(const {'kyc_status': 'approved'}).isVerified, isTrue);
      expect(KycStatusInfo.fromJson(const {'kyc_status': 'pending'}).isPending, isTrue);
      expect(KycStatusInfo.fromJson(const {'kyc_status': 'in_review'}).isPending, isTrue);
      expect(KycStatusInfo.fromJson(const {'kyc_status': 'rejected'}).isVerified, isFalse);
    });

    test('defaults to not_required with no providers', () {
      final status = KycStatusInfo.fromJson(const {});
      expect(status.status, 'not_required');
      expect(status.providers, isEmpty);
      expect(status.providerEnabled, isFalse);
    });

    test('parses rejection reason', () {
      final status = KycStatusInfo.fromJson({
        'kyc_status': 'rejected',
        'kyc_rejection_reason': 'Document unreadable',
      });
      expect(status.rejectionReason, 'Document unreadable');
    });
  });

  group('RoleApplication (account upgrade flow)', () {
    test('parses a pending application', () {
      final app = RoleApplication.fromJson({
        'id': 9,
        'previous_role': 'member',
        'requested_role': 'creator',
        'status': 'pending',
        'requested_at': '2026-08-01T10:00:00Z',
      });
      expect(app.id, 9);
      expect(app.previousRole, 'member');
      expect(app.requestedRole, 'creator');
      expect(app.status, 'pending');
      expect(app.requestedAt, '2026-08-01T10:00:00Z');
      expect(app.rejectionReason, isNull);
    });

    test('parses a rejected application with reason', () {
      final app = RoleApplication.fromJson({
        'id': 3,
        'previous_role': 'member',
        'requested_role': 'vendor',
        'status': 'rejected',
        'rejection_reason': 'KYC not completed',
      });
      expect(app.status, 'rejected');
      expect(app.rejectionReason, 'KYC not completed');
    });

    test('defaults to pending when status missing', () {
      final app = RoleApplication.fromJson(const {'id': 1});
      expect(app.status, 'pending');
      expect(app.id, 1);
    });
  });
}
