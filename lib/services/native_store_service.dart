import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/api_client.dart';
import '../providers/gifts_provider.dart';

/// Outcome of a native store coin purchase.
///
/// [canFallback] is true when the native store is not configured or offers no
/// product for the pack — in that case the caller may retry via the online
/// payment flow (dev/backup path).
class NativePurchaseOutcome {
  const NativePurchaseOutcome({
    required this.ok,
    this.error,
    this.coinsAdded,
    this.canFallback = false,
  });

  final bool ok;
  final String? error;
  final int? coinsAdded;
  final bool canFallback;
}

class _PendingRequest {
  _PendingRequest({required this.completer, required this.coinPackId});
  final Completer<NativePurchaseOutcome> completer;
  final int? coinPackId;
}

/// Wraps the App Store (StoreKit) and Google Play Billing flows for coin packs.
///
/// Purchases are verified against the MurihSpace backend
/// (`POST /coins/native-verify`) which validates them server-to-server with
/// Apple / Google; the store transaction is completed only after verification.
class NativeStoreService {
  NativeStoreService._();

  static final NativeStoreService instance = NativeStoreService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, _PendingRequest> _pending = {};
  bool _listening = false;

  /// `'apple'` | `'google'` | `''` when the runtime cannot do native billing.
  String get store {
    if (kIsWeb) return '';
    if (Platform.isIOS) return 'apple';
    if (Platform.isAndroid) return 'google';
    return '';
  }

  bool get isNative => store.isNotEmpty;

  void init() {
    if (!isNative || _listening) return;
    _listening = true;
    _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        for (final req in _pending.values) {
          if (!req.completer.isCompleted) {
            req.completer.complete(const NativePurchaseOutcome(
              ok: false,
              error: 'In-app purchase stream error.',
            ));
          }
        }
        _pending.clear();
      },
    );
  }

  /// Buys a native coin pack. Completes when the store transaction has been
  /// verified by the backend and the coins were credited.
  Future<NativePurchaseOutcome> purchase(CoinPack pack) async {
    if (!isNative) {
      return const NativePurchaseOutcome(
        ok: false,
        canFallback: true,
        error: 'Native billing is unavailable on this platform.',
      );
    }

    init();

    final productId = await _resolveProductId(pack);
    if (productId == null) {
      return const NativePurchaseOutcome(
        ok: false,
        canFallback: true,
        error: 'This coin pack is not available for in-app purchase yet.',
      );
    }

    if (!await _iap.isAvailable()) {
      return const NativePurchaseOutcome(
        ok: false,
        canFallback: false,
        error: 'In-app billing is not available on this device.',
      );
    }

    final response = await _iap.queryProductDetails({productId});
    final product = response.productDetails
        .where((d) => d.id == productId)
        .toList()
        .firstOrNull;

    if (product == null) {
      return const NativePurchaseOutcome(
        ok: false,
        canFallback: true,
        error: 'This coin pack is not available in the store yet.',
      );
    }

    final completer = Completer<NativePurchaseOutcome>();
    _pending[productId] = _PendingRequest(
      completer: completer,
      coinPackId: pack.id,
    );

    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

      if (!started) {
        _pending.remove(productId);
        return const NativePurchaseOutcome(
          ok: false,
          canFallback: false,
          error: 'The purchase did not start.',
        );
      }

      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          _pending.remove(productId);
          return const NativePurchaseOutcome(
            ok: false,
            canFallback: false,
            error: 'Purchase timed out.',
          );
        },
      );
    } catch (e) {
      _pending.remove(productId);
      return NativePurchaseOutcome(
        ok: false,
        canFallback: false,
        error: 'Purchase failed: $e',
      );
    }
  }

  Future<String?> _resolveProductId(CoinPack pack) async {
    final currentStore = store;
    try {
      final response = await ApiClient.instance.dio.post(
        '/coins/native-intent',
        data: {'coin_pack_id': pack.id, 'store': currentStore},
      );
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (data is Map<String, dynamic>) {
        final id = data['product_id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    } on DioException {
      // Native billing is not configured (503) or unreachable — fall back.
      return null;
    } catch (_) {
      return null;
    }
    return null;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          _emitFor(
            p.productID,
            ok: false,
            error: p.error?.message ?? 'Store purchase failed.',
          );
          _completeIfNeeded(p);
        case PurchaseStatus.canceled:
        case PurchaseStatus.unknown:
          _emitFor(p.productID, ok: false, error: 'Purchase canceled.');
          _completeIfNeeded(p);
        case PurchaseStatus.purchased:
          _handlePurchased(p);
        case PurchaseStatus.restored:
          _completeIfNeeded(p);
      }
    }
  }

  Future<void> _handlePurchased(PurchaseDetails p) async {
    final currentStore = store;
    final req = _pending[p.productID];

    final token = p.verificationData.serverVerificationData;

    if (token.isEmpty) {
      _emitFor(
        p.productID,
        ok: false,
        error: 'The store did not return verification data.',
      );
      _completeIfNeeded(p);
      return;
    }

    final outcome = await _verifyOnBackend(
      store: currentStore,
      coinPackId: req?.coinPackId,
      productId: p.productID,
      token: token,
      transactionId: currentStore == 'apple' ? p.purchaseID : null,
      orderId: currentStore == 'google' ? p.purchaseID : null,
    );

    _emitFor(p.productID, outcome: outcome);
    _completeIfNeeded(p);
  }

  Future<NativePurchaseOutcome> _verifyOnBackend({
    required String store,
    int? coinPackId,
    required String productId,
    required String token,
    String? transactionId,
    String? orderId,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post(
        '/coins/native-verify',
        data: {
          if (coinPackId != null) 'coin_pack_id': coinPackId,
          'store': store,
          'product_id': productId,
          'token': token,
          if (transactionId != null && transactionId.isNotEmpty)
            'transaction_id': transactionId,
          if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
        },
      );

      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final coins = data is Map<String, dynamic>
          ? (data['credited_coins'] as num?)?.toInt()
          : null;

      return NativePurchaseOutcome(ok: true, coinsAdded: coins);
    } on DioException catch (e) {
      final message = _extractPurchaseError(e);
      return NativePurchaseOutcome(ok: false, error: message);
    } catch (e) {
      return NativePurchaseOutcome(ok: false, error: 'Verification failed: $e');
    }
  }

  String _extractPurchaseError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
        }
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return 'Purchase could not be verified.';
  }

  void _emitFor(
    String productId, {
    bool? ok,
    NativePurchaseOutcome? outcome,
    String? error,
  }) {
    final req = _pending.remove(productId);
    if (req == null || req.completer.isCompleted) return;
    final resolved = outcome ??
        NativePurchaseOutcome(ok: ok ?? false, error: error ?? 'Purchase failed.');
    req.completer.complete(resolved);
  }

  Future<void> _completeIfNeeded(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(p);
    } catch (_) {
      // A failed completion is retried from the next purchase stream event.
    }
  }
}

