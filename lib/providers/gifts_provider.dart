import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/currency_formatter.dart';
import '../services/native_store_service.dart';

class GiftItem {
  final int id;
  final String name;
  final String? iconUrl;
  final int coinPrice;
  final int creatorEarns;
  final String category;

  GiftItem({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.coinPrice,
    required this.creatorEarns,
    required this.category,
  });

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      iconUrl: json['icon_url']?.toString(),
      coinPrice: (json['coin_price'] as num?)?.toInt() ?? 0,
      creatorEarns: (json['creator_earns'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'standard',
    );
  }
}

class CoinPack {
  final int id;
  final String name;
  final int coins;
  final int bonusCoins;
  final int price;
  final String currency;
  final String? badge;
  final String localFormatted;
  final String localCurrency;
  final double localPrice;

  CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.bonusCoins,
    required this.price,
    required this.currency,
    required this.badge,
    this.localFormatted = '',
    this.localCurrency = 'NGN',
    this.localPrice = 0.0,
  });

  int get totalCoins => coins + bonusCoins;

  factory CoinPack.fromJson(Map<String, dynamic> json) {
    return CoinPack(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      bonusCoins: (json['bonus_coins'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      badge: json['badge']?.toString(),
      localFormatted: json['local_formatted']?.toString() ?? '',
      localCurrency: json['local_currency']?.toString() ?? 'NGN',
      localPrice: (json['local_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WalletInfo {
  final int balance;
  final String currency;

  WalletInfo({required this.balance, required this.currency});

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'NGN',
    );
  }
}

class GiftTransaction {
  final int id;
  final String giftName;
  final String? senderName;
  final int coinPrice;
  final String createdAt;

  GiftTransaction({
    required this.id,
    required this.giftName,
    required this.senderName,
    required this.coinPrice,
    required this.createdAt,
  });

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    final gift = json['gift'] as Map<String, dynamic>?;
    final sender = json['sender'] as Map<String, dynamic>?;
    return GiftTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      giftName: gift?['name']?.toString() ?? 'Gift',
      senderName: sender?['name']?.toString(),
      coinPrice: (json['coin_price'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class GiftsState {
  final bool loading;
  final List<GiftItem> gifts;
  final List<CoinPack> packs;
  final List<GiftTransaction> transactions;
  final WalletInfo? wallet;
  final double coinRate;
  final double minPurchaseUsd;
  final double maxPurchaseUsd;
  final String? error;

  GiftsState({
    this.loading = false,
    this.gifts = const [],
    this.packs = const [],
    this.transactions = const [],
    this.wallet,
    this.coinRate = 10.0,
    this.minPurchaseUsd = 1.0,
    this.maxPurchaseUsd = 10000.0,
    this.error,
  });

  GiftsState copyWith({
    bool? loading,
    List<GiftItem>? gifts,
    List<CoinPack>? packs,
    List<GiftTransaction>? transactions,
    WalletInfo? wallet,
    double? coinRate,
    double? minPurchaseUsd,
    double? maxPurchaseUsd,
    String? error,
    bool clearError = false,
  }) {
    return GiftsState(
      loading: loading ?? this.loading,
      gifts: gifts ?? this.gifts,
      packs: packs ?? this.packs,
      transactions: transactions ?? this.transactions,
      wallet: wallet ?? this.wallet,
      coinRate: coinRate ?? this.coinRate,
      minPurchaseUsd: minPurchaseUsd ?? this.minPurchaseUsd,
      maxPurchaseUsd: maxPurchaseUsd ?? this.maxPurchaseUsd,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GiftsNotifier extends Notifier<GiftsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  GiftsState build() {
    return GiftsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _dio.get('/gifts/catalogue'),
        _dio.get('/coins/packs'),
        _dio.get('/gifts/transactions'),
        _dio.get('/wallet'),
      ]);

      final api = ApiClient.instance;
      final gifts = api.unwrapList<GiftItem>(results[0], GiftItem.fromJson);
      final packs = api.unwrapList<CoinPack>(results[1], CoinPack.fromJson);
      final txnList = api.unwrapList<GiftTransaction>(results[2], GiftTransaction.fromJson);

      // The packs catalogue also carries the admin-tunable USD → MSH rate.
      double coinRate = 10.0;
      double minPurchaseUsd = 1.0;
      double maxPurchaseUsd = 10000.0;
      final packsPayload = api.unwrap(results[1]);
      if (packsPayload is Map<String, dynamic>) {
        coinRate = (packsPayload['coin_conversion_rate'] as num?)?.toDouble() ?? 10.0;
        minPurchaseUsd = (packsPayload['min_purchase_usd'] as num?)?.toDouble() ?? 1.0;
        maxPurchaseUsd = (packsPayload['max_purchase_usd'] as num?)?.toDouble() ?? 10000.0;
      }
      CurrencyFormatter.setCoinRate(coinRate);

      // Sprint 9: GET /wallet now returns a LIST of multi-type wallets.
      // Coin balance lives on the system wallet's available balance.
      final wallets = api.unwrapList<dynamic>(results[3], (json) => json);
      WalletInfo? walletInfo;
      for (final raw in wallets) {
        if (raw is Map<String, dynamic> && raw['wallet_type'] == 'system') {
          walletInfo = WalletInfo(
            balance: (raw['available'] as num?)?.toInt() ?? 0,
            currency: raw['currency'] as String? ?? 'NGN',
          );
          break;
        }
      }

      state = GiftsState(
        loading: false,
        gifts: gifts,
        packs: packs,
        transactions: txnList,
        wallet: walletInfo,
        coinRate: coinRate,
        minPurchaseUsd: minPurchaseUsd,
        maxPurchaseUsd: maxPurchaseUsd,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: _dioError(e),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Failed to load gifts.');
    }
  }

  Future<bool> buyPack(CoinPack pack) async {
    // Native apps buy coin packs through the App Store / Google Play flow.
    // Every other runtime (web debug, desktop) keeps the online payment path.
    final native = NativeStoreService.instance;
    if (native.isNative) {
      final outcome = await native.purchase(pack);
      if (outcome.ok) {
        await loadAll();
        return true;
      }
      if (!outcome.canFallback) {
        state = state.copyWith(error: outcome.error ?? 'In-app purchase failed.');
        return false;
      }
    }

    return _buyPackOnline(pack);
  }

  Future<bool> _buyPackOnline(CoinPack pack) async {
    try {
      final response = await _dio.post(
        '/coins/purchase',
        data: {'coin_pack_id': pack.id, 'reference': ApiClient.generateIdempotencyKey()},
      );
      // The purchase response returns a CoinPurchase record, not a wallet.
      // Reload the full wallet/gifts state so balances are server-sourced.
      await loadAll();
      return response.statusCode == 201;
    } on DioException catch (e) {
      state = state.copyWith(error: _dioError(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Purchase failed.');
      return false;
    }
  }

  /// Purchases MSH coins for a custom manual USD amount ("how much do you want").
  Future<int?> buyCustom(double usdAmount) async {
    if (usdAmount <= 0) {
      state = state.copyWith(error: 'Enter a valid USD amount.');
      return null;
    }
    try {
      final response = await _dio.post(
        '/coins/purchase-custom',
        data: {
          'amount_usd': usdAmount,
          'reference': ApiClient.generateIdempotencyKey(),
        },
      );
      final body = response.data;
      final payload = body is Map<String, dynamic> ? body['data'] : null;
      final inner = payload is Map<String, dynamic> ? payload['data'] : null;
      final coins = inner is Map<String, dynamic> ? (inner['coins_added'] as num?)?.toInt() : null;
      await loadAll();
      return coins ?? (usdAmount * (state.coinRate > 0 ? state.coinRate : 10)).round();
    } on DioException catch (e) {
      state = state.copyWith(error: _dioError(e));
      return null;
    } catch (_) {
      state = state.copyWith(error: 'Purchase failed.');
      return null;
    }
  }

  Future<bool> sendGift({
    required int giftId,
    required int recipientId,
    String? message,
    bool isAnonymous = false,
    String walletType = 'system',
  }) async {
    try {
      await _dio.post(
        '/gifts/send',
        data: {
          'gift_id': giftId,
          'recipient_id': recipientId,
          'is_anonymous': isAnonymous,
          'wallet_type': walletType,
          if (message != null && message.isNotEmpty) 'message': message,
          'idempotency_key': ApiClient.generateIdempotencyKey(),
        },
      );
      await loadAll();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _dioError(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Failed to send gift.');
      return false;
    }
  }

  String _dioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final data = e.response?.data as Map<String, dynamic>;
      return data['message'] as String? ?? 'Request failed.';
    }
    return 'Network error.';
  }
}

final giftsProvider = NotifierProvider<GiftsNotifier, GiftsState>(() {
  return GiftsNotifier();
});
