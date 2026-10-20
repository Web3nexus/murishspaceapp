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
  final double amountUsd;
  final int coins;
  final String localCurrency;
  final double localRate;
  final double localEstimatedAvailable;
  final String localFormatted;
  final bool hasPin;
  final String status;
  /// Money is withdrawable, but the owner has not verified their identity, so withdrawals are refused.
  final bool kycRequiredToWithdraw;

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
    required this.amountUsd,
    required this.coins,
    required this.localCurrency,
    required this.localRate,
    required this.localEstimatedAvailable,
    required this.localFormatted,
    required this.hasPin,
    required this.status,
    this.kycRequiredToWithdraw = false,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final available = (json['available'] as num?)?.toInt() ?? 0;
    final currency = json['currency'] as String? ?? 'USD';
    final amountUsd = (json['amount_usd'] as num?)?.toDouble() ?? (available / 100.0);
    final localRate = (json['local_rate'] as num?)?.toDouble() ?? 0.0;
    final localEstimated = (json['local_estimated_available'] as num?)?.toDouble() ?? (amountUsd * localRate);

    return Wallet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: WalletType.fromApi(json['wallet_type'] as String? ?? 'system'),
      available: available,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      reserved: (json['reserved'] as num?)?.toInt() ?? 0,
      escrow: (json['escrow'] as num?)?.toInt() ?? 0,
      withdrawable: (json['withdrawable'] as num?)?.toInt() ?? 0,
      nonWithdrawable: (json['non_withdrawable'] as num?)?.toInt() ?? 0,
      disputed: (json['disputed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      currency: currency,
      amountUsd: amountUsd,
      coins: (json['coins'] as num?)?.toInt() ?? available,
      localCurrency: json['local_currency'] as String? ?? 'USD',
      localRate: localRate,
      localEstimatedAvailable: localEstimated,
      localFormatted: json['local_formatted'] as String? ?? '',
      hasPin: json['has_pin'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      kycRequiredToWithdraw: json['kyc_required_to_withdraw'] as bool? ?? false,
    );
  }

  /// Human-readable money string using the backend minor-unit format (e.g. $1,000.00).
  String get formatted {
    final syms = {'USD': r'$', 'NGN': '₦', 'GBP': '£', 'EUR': '€'};
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

class WalletTransaction {
  final int id;
  final String description;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.description,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? json['title'] as String? ?? 'Transaction',
      type: json['type'] as String? ?? 'credit',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// An order escrow from `GET /wallet/escrow`. Only escrows where funds are
/// still locked (held / on hold / disputed) count as active deals.
class EscrowDeal {
  final int id;
  final String title;
  final int amount;
  final String currency;
  final String status;
  final String? holdReason;
  final String? deliveryKind;
  final DateTime? deliveredAt;
  final DateTime? buyerConfirmedAt;
  final DateTime? releaseAt;
  final int buyerId;
  final int sellerId;
  final DateTime createdAt;

  const EscrowDeal({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.status,
    this.holdReason,
    this.deliveryKind,
    this.deliveredAt,
    this.buyerConfirmedAt,
    this.releaseAt,
    this.buyerId = 0,
    this.sellerId = 0,
    required this.createdAt,
  });

  bool get isOnHold => status == 'on_hold';
  bool get isActive => status == 'held' || status == 'on_hold' || status == 'disputed';

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory EscrowDeal.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    final order = rawOrder is Map ? rawOrder : null;
    final orderNumber = order?['order_number']?.toString();
    return EscrowDeal(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (orderNumber != null && orderNumber.isNotEmpty) ? 'Order $orderNumber' : 'Escrow #${json['id']}',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'held',
      holdReason: json['hold_reason'] as String?,
      deliveryKind: json['delivery_kind'] as String?,
      deliveredAt: _date(json['delivered_at']),
      buyerConfirmedAt: _date(json['buyer_confirmed_at']),
      releaseAt: _date(json['release_at']),
      buyerId: (json['buyer_id'] as num?)?.toInt() ?? 0,
      sellerId: (json['seller_id'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// A refund from a dispute the buyer won. It stays on the platform: it can be spent,
/// or sent back to the card that paid (`POST /wallet/refund-balances/{id}/refund-to-card`).
class RefundBalance {
  final int id;
  final int orderId;
  final int amountUsd;
  final String originalAmount;
  final String originalCurrency;
  final String status;
  final String? failureReason;

  const RefundBalance({
    required this.id,
    required this.orderId,
    required this.amountUsd,
    required this.originalAmount,
    required this.originalCurrency,
    required this.status,
    this.failureReason,
  });

  bool get canSendToCard => status == 'available';

  factory RefundBalance.fromJson(Map<String, dynamic> json) {
    return RefundBalance(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      amountUsd: (json['amount_usd'] as num?)?.toInt() ?? 0,
      originalAmount: '${json['original_amount'] ?? ''}',
      originalCurrency: json['original_currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'available',
      failureReason: json['failure_reason'] as String?,
    );
  }
}

class WalletState {
  final bool loading;
  final String? error;
  final List<Wallet> wallets;
  final List<WalletTransaction> transactions;
  final List<EscrowDeal> escrows;
  final List<RefundBalance> refundBalances;
  final FeePreview? feePreview;

  const WalletState({
    this.loading = false,
    this.error,
    this.wallets = const [],
    this.transactions = const [],
    this.escrows = const [],
    this.refundBalances = const [],
    this.feePreview,
  });

  double get systemBalance {
    final sysWallet = wallets.firstWhere(
      (w) => w.type == WalletType.system,
      orElse: () => const Wallet(
        id: 0,
        type: WalletType.system,
        available: 0,
        pending: 0,
        reserved: 0,
        escrow: 0,
        withdrawable: 0,
        nonWithdrawable: 0,
        disputed: 0,
        total: 0,
        currency: 'USD',
        amountUsd: 0.0,
        coins: 0,
        localCurrency: 'USD',
        localRate: 0.0,
        localEstimatedAvailable: 0.0,
        localFormatted: '',
        hasPin: false,
        status: 'active',
      ),
    );
    return sysWallet.available / 100.0;
  }

  int get coinsBalance {
    final sysWallet = wallets.firstWhere(
      (w) => w.type == WalletType.system,
      orElse: () => const Wallet(
        id: 0,
        type: WalletType.system,
        available: 0,
        pending: 0,
        reserved: 0,
        escrow: 0,
        withdrawable: 0,
        nonWithdrawable: 0,
        disputed: 0,
        total: 0,
        currency: 'USD',
        amountUsd: 0.0,
        coins: 0,
        localCurrency: 'USD',
        localRate: 0.0,
        localEstimatedAvailable: 0.0,
        localFormatted: '',
        hasPin: false,
        status: 'active',
      ),
    );
    return sysWallet.coins;
  }

  double get creatorBalance {
    final creatorWallet = wallets.firstWhere(
      (w) => w.type == WalletType.creator,
      orElse: () => const Wallet(
        id: 0,
        type: WalletType.creator,
        available: 0,
        pending: 0,
        reserved: 0,
        escrow: 0,
        withdrawable: 0,
        nonWithdrawable: 0,
        disputed: 0,
        total: 0,
        currency: 'USD',
        amountUsd: 0.0,
        coins: 0,
        localCurrency: 'USD',
        localRate: 0.0,
        localEstimatedAvailable: 0.0,
        localFormatted: '',
        hasPin: false,
        status: 'active',
      ),
    );
    return creatorWallet.available / 100.0;
  }

  double get businessEscrowBalance {
    final bizWallet = wallets.firstWhere(
      (w) => w.type == WalletType.business,
      orElse: () => const Wallet(
        id: 0,
        type: WalletType.business,
        available: 0,
        pending: 0,
        reserved: 0,
        escrow: 0,
        withdrawable: 0,
        nonWithdrawable: 0,
        disputed: 0,
        total: 0,
        currency: 'USD',
        amountUsd: 0.0,
        coins: 0,
        localCurrency: 'USD',
        localRate: 0.0,
        localEstimatedAvailable: 0.0,
        localFormatted: '',
        hasPin: false,
        status: 'active',
      ),
    );
    return bizWallet.escrow / 100.0;
  }

  /// Escrows where funds are still locked (held or disputed).
  List<EscrowDeal> get escrowDeals =>
      escrows.where((e) => e.isActive).toList();

  int get escrowsLockedMinor {
    var total = 0;
    for (final e in escrowDeals) {
      total += e.amount;
    }
    return total;
  }

  WalletState copyWith({
    bool? loading,
    String? error,
    List<Wallet>? wallets,
    List<WalletTransaction>? transactions,
    List<EscrowDeal>? escrows,
    List<RefundBalance>? refundBalances,
    FeePreview? feePreview,
    bool clearError = false,
  }) {
    return WalletState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      wallets: wallets ?? this.wallets,
      transactions: transactions ?? this.transactions,
      escrows: escrows ?? this.escrows,
      refundBalances: refundBalances ?? this.refundBalances,
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

      List<WalletTransaction> txList = [];
      try {
        final txRes = await _dio.get('/wallet/transactions');
        txList = ApiClient.instance.unwrapList<WalletTransaction>(txRes, WalletTransaction.fromJson);
      } catch (_) {}

      List<EscrowDeal> escrowList = [];
      try {
        final escrowRes = await _dio.get('/wallet/escrow');
        escrowList = ApiClient.instance.unwrapList<EscrowDeal>(escrowRes, EscrowDeal.fromJson);
      } catch (_) {}

      List<RefundBalance> refundList = [];
      try {
        final refundRes = await _dio.get('/wallet/refund-balances');
        refundList = ApiClient.instance.unwrapList<RefundBalance>(refundRes, RefundBalance.fromJson);
      } catch (_) {}

      state = WalletState(
        wallets: list,
        transactions: txList,
        escrows: escrowList,
        refundBalances: refundList,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load wallets.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// POST /wallet/escrow/{id}/{action}: `resume`, `confirm-receipt`, `release-now`, or `dispute`
  /// (with `reason`). Returns null on success, or the message to show.
  Future<String?> escrowAction(int id, String action, {Map<String, dynamic>? data}) async {
    try {
      await _dio.post('/wallet/escrow/$id/$action', data: data);
      await _load();
      return null;
    } on DioException catch (e) {
      return _errorMessage(e);
    } catch (_) {
      return 'That action could not be completed.';
    }
  }

  /// POST /wallet/refund-balances/{id}/refund-to-card. Returns null on success, or the message to show.
  Future<String?> refundToCard(int id) async {
    try {
      await _dio.post('/wallet/refund-balances/$id/refund-to-card');
      await _load();
      return null;
    } on DioException catch (e) {
      return _errorMessage(e);
    } catch (_) {
      return 'The refund could not be sent to the card.';
    }
  }

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
    String currency = 'USD',
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

  /// POST /withdrawals/preview — live payout calculation and rate lock.
  Future<Map<String, dynamic>?> previewWithdrawal({
    required int amountUsdCents,
    String destinationCurrency = 'NGN',
    String walletType = 'creator',
  }) async {
    try {
      final response = await _dio.post('/withdrawals/preview', data: {
        'amount': amountUsdCents,
        'destination_currency': destinationCurrency,
        'wallet_type': walletType,
      });
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /withdrawals — submit withdrawal request.
  Future<bool> submitWithdrawal({
    required int amountUsdCents,
    required String pin,
    String destinationCurrency = 'NGN',
    String walletType = 'creator',
  }) async {
    try {
      await _dio.post('/withdrawals', data: {
        'amount': amountUsdCents,
        'currency': destinationCurrency,
        'wallet_type': walletType,
        'pin': pin,
      });
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Withdrawal failed.');
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
