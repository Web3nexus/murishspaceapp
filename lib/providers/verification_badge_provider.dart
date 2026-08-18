import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// Paid verification badge status (Sprint 2 — verification badge logic).
class BadgeStatus {
  final String status;
  final String? expiresAt;
  final String? purchasedAt;
  final bool autoRenew;
  final bool kycVerified;
  final int monthlyFee;
  final int walletBalance;

  const BadgeStatus({
    required this.status,
    this.expiresAt,
    this.purchasedAt,
    required this.autoRenew,
    required this.kycVerified,
    required this.monthlyFee,
    required this.walletBalance,
  });

  factory BadgeStatus.fromJson(Map<String, dynamic> json) {
    return BadgeStatus(
      status: json['status'] as String? ?? 'not_applied',
      expiresAt: json['expires_at'] as String?,
      purchasedAt: json['purchased_at'] as String?,
      autoRenew: json['auto_renew'] as bool? ?? false,
      kycVerified: json['kyc_verified'] as bool? ?? false,
      monthlyFee: (json['monthly_fee'] as num?)?.toInt() ?? 0,
      walletBalance: (json['wallet_balance'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isActive => status == 'verified' || status == 'active';
  bool get isPending => status == 'under_review' || status == 'payment_pending' || status == 'kyc_pending';
}

class VerificationBadgeState {
  final bool loading;
  final String? error;
  final BadgeStatus? status;

  const VerificationBadgeState({
    this.loading = false,
    this.error,
    this.status,
  });

  VerificationBadgeState copyWith({
    bool? loading,
    String? error,
    BadgeStatus? status,
    bool clearError = false,
  }) {
    return VerificationBadgeState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
    );
  }
}

class VerificationBadgeNotifier extends Notifier<VerificationBadgeState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  VerificationBadgeState build() {
    _load();
    return const VerificationBadgeState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/verification-badge/status');
      final payload = ApiClient.instance.unwrap(response);
      state = VerificationBadgeState(
        status: BadgeStatus.fromJson(payload is Map<String, dynamic> ? payload : {}),
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load badge status.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// POST /verification-badge/apply — apply for the paid badge.
  Future<bool> apply({String billingCycle = 'annual'}) async {
    try {
      await _dio.post('/verification-badge/apply', data: {'billing_cycle': billingCycle});
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not apply for the badge.');
      return false;
    }
  }

  /// POST /verification-badge/renew — renew an active badge.
  Future<bool> renew() async {
    try {
      await _dio.post('/verification-badge/renew');
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not renew the badge.');
      return false;
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? 'Request failed.';
    }
    return 'Request failed.';
  }
}

final verificationBadgeProvider =
    NotifierProvider<VerificationBadgeNotifier, VerificationBadgeState>(
  VerificationBadgeNotifier.new,
);
