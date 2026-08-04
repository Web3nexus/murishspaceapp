import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// Wallet type per the Sprint 9 multi-wallet redesign.
enum WalletType {
  system('system'),
  creator('creator'),
  business('business');

  final String apiValue;
  const WalletType(this.apiValue);

  static WalletType fromApi(String value) => switch (value) {
        'creator' => WalletType.creator,
        'business' => WalletType.business,
        _ => WalletType.system,
      };
}

/// A single wallet with the balance categories from the backend contract.
class Wallet {
  final int id;
  final WalletType type;
  final int available;
  final int pending;
  final int reserved;
  final int escrow;
  final int withdrawable;
  final int nonWithdrawable;
  final int disputed;
  final int total;
  final String currency;
  final bool hasPin;
  final String status;

  const Wallet({
    required this.id,
    required this.type,
    required this.available,
    required this.pending,
    required this.reserved,
    required this.escrow,
    required this.withdrawable,
    required this.nonWithdrawable,
    required this.disputed,
    required this.total,
    required this.currency,
    required this.hasPin,
    required this.status,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: WalletType.fromApi(json['wallet_type'] as String? ?? 'system'),
      available: (json['available'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      reserved: (json['reserved'] as num?)?.toInt() ?? 0,
      escrow: (json['escrow'] as num?)?.toInt() ?? 0,
      withdrawable: (json['withdrawable'] as num?)?.toInt() ?? 0,
      nonWithdrawable: (json['non_withdrawable'] as num?)?.toInt() ?? 0,
      disputed: (json['disputed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      hasPin: json['has_pin'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// Human-readable money string using the backend minor-unit format (e.g. NGN 1,000.00).
  String get formatted {
    final syms = {'NGN': '₦', 'USD': r'$', 'GBP': '£', 'EUR': '€'};
    final sym = syms[currency] ?? '$currency ';
    return '$sym${(available / 100).toStringAsFixed(2)}';
  }
}

/// Fee preview returned by `POST /wallet/fees/preview`.
class FeePreview {
  final int grossAmount;
  final int platformFee;
  final int processingFee;
  final int recipientAmount;
  final int totalCharged;
  final String currency;

  const FeePreview({
    required this.grossAmount,
    required this.platformFee,
    required this.processingFee,
    required this.recipientAmount,
    required this.totalCharged,
    required this.currency,
  });

  factory FeePreview.fromJson(Map<String, dynamic> json) {
    return FeePreview(
      grossAmount: (json['gross_amount'] as num?)?.toInt() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toInt() ?? 0,
      processingFee: (json['processing_fee'] as num?)?.toInt() ?? 0,
      recipientAmount: (json['net_amount'] as num?)?.toInt() ??
          (json['recipient_amount'] as num?)?.toInt() ??
          0,
      totalCharged: (json['total_charged'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class WalletState {
  final bool loading;
  final String? error;
  final List<Wallet> wallets;
  final FeePreview? feePreview;

  const WalletState({
    this.loading = false,
    this.error,
    this.wallets = const [],
    this.feePreview,
  });

  WalletState copyWith({
    bool? loading,
    String? error,
    List<Wallet>? wallets,
    FeePreview? feePreview,
    bool clearError = false,
  }) {
    return WalletState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      wallets: wallets ?? this.wallets,
      feePreview: feePreview ?? this.feePreview,
    );
  }
}

class WalletNotifier extends Notifier<WalletState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  WalletState build() {
    _load();
    return const WalletState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/wallet');
      final list = ApiClient.instance.unwrapList<Wallet>(response, Wallet.fromJson);
      state = WalletState(wallets: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load wallets.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  Wallet? walletOf(WalletType type) {
    for (final w in state.wallets) {
      if (w.type == type) return w;
    }
    return null;
  }

  /// POST /wallet/fees/preview — show fees before confirming a transaction.
  Future<FeePreview?> previewFees({
    required int amount,
    required String code,
    String? currency,
  }) async {
    try {
      final response = await _dio.post('/wallet/fees/preview', data: {
        'transaction_code': code,
        'amount': amount,
        'currency': ?currency,
      });
      final payload = ApiClient.instance.unwrap(response);
      final preview = FeePreview.fromJson(payload as Map<String, dynamic>);
      state = state.copyWith(feePreview: preview, clearError: true);
      return preview;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return null;
    } catch (_) {
      state = state.copyWith(error: 'Could not preview fees.');
      return null;
    }
  }

  /// POST /wallet/deposit — idempotent cash deposit into the system wallet.
  Future<bool> deposit({
    required int amount,
    String currency = 'NGN',
    String paymentGateway = 'paystack',
  }) async {
    try {
      await _dio.post('/wallet/deposit', data: {
        'amount': amount,
        'currency': currency,
        'payment_gateway': paymentGateway,
        'idempotency_key': ApiClient.generateIdempotencyKey(),
      });
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Deposit failed.');
      return false;
    }
  }

  /// POST /wallet/internal-transfer — creator/business earnings → system wallet.
  Future<bool> internalTransfer({
    required String fromType,
    required int amount,
  }) async {
    try {
      await _dio.post('/wallet/internal-transfer', data: {
        'from_wallet_type': fromType,
        'to_wallet_type': 'system',
        'amount': amount,
        'idempotency_key': ApiClient.generateIdempotencyKey(),
      });
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Transfer failed.');
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

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);
