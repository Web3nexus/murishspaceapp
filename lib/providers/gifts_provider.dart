import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

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
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      coinPrice: (json['coin_price'] as num?)?.toInt() ?? 0,
      creatorEarns: (json['creator_earns'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'standard',
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

  CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.bonusCoins,
    required this.price,
    required this.currency,
    required this.badge,
  });

  int get totalCoins => coins + bonusCoins;

  factory CoinPack.fromJson(Map<String, dynamic> json) {
    return CoinPack(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      bonusCoins: (json['bonus_coins'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      badge: json['badge'] as String?,
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
      currency: json['currency'] as String? ?? 'NGN',
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
      id: (json['id'] as num).toInt(),
      giftName: gift?['name'] as String? ?? 'Gift',
      senderName: sender?['name'] as String?,
      coinPrice: (json['coin_price'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class GiftsState {
  final bool loading;
  final List<GiftItem> gifts;
  final List<CoinPack> packs;
  final List<GiftTransaction> transactions;
  final WalletInfo? wallet;
  final String? error;

  GiftsState({
    this.loading = false,
    this.gifts = const [],
    this.packs = const [],
    this.transactions = const [],
    this.wallet,
    this.error,
  });

  GiftsState copyWith({
    bool? loading,
    List<GiftItem>? gifts,
    List<CoinPack>? packs,
    List<GiftTransaction>? transactions,
    WalletInfo? wallet,
    String? error,
    bool clearError = false,
  }) {
    return GiftsState(
      loading: loading ?? this.loading,
      gifts: gifts ?? this.gifts,
      packs: packs ?? this.packs,
      transactions: transactions ?? this.transactions,
      wallet: wallet ?? this.wallet,
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
