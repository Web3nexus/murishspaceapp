import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/marketplace_models.dart';

/// State wrapper for Marketplace products list and filters.
class MarketplaceState {
  final List<MarketplaceProduct> products;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final String currentLocation;
  final String searchQuery;

  MarketplaceState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = 'Explore',
    this.currentLocation = 'Lagos, Nigeria',
    this.searchQuery = '',
  });

  MarketplaceState copyWith({
    List<MarketplaceProduct>? products,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? currentLocation,
    String? searchQuery,
  }) {
    return MarketplaceState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      currentLocation: currentLocation ?? this.currentLocation,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  MarketplaceState build() {
    fetchProducts();
    return MarketplaceState(isLoading: true);
  }

  Future<void> fetchProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final queryParams = <String, dynamic>{};
      if (state.selectedCategory.isNotEmpty &&
          state.selectedCategory != 'Explore' &&
          state.selectedCategory != 'All') {
        queryParams['category'] = state.selectedCategory;
      }
      if (state.searchQuery.isNotEmpty) {
        queryParams['search'] = state.searchQuery;
      }

      final response = await _dio.get('/marketplace', queryParameters: queryParams);
      final payload = ApiClient.instance.unwrap(response);
      List<dynamic> listRaw = [];
      if (payload is List) {
        listRaw = payload;
      } else if (payload is Map<String, dynamic>) {
        listRaw = (payload['data'] as List<dynamic>?) ?? [];
      }

      final list = listRaw
          .map((e) => MarketplaceProduct.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(products: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        products: [],
        isLoading: false,
        error: 'Unable to load products. Pull down to refresh.',
      );
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    fetchProducts();
  }

  void setLocation(String location) {
    state = state.copyWith(currentLocation: location);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchProducts();
  }

  Future<MarketplaceProduct?> createProduct({
    required String title,
    required String description,
    required double price,
    String currency = 'USD',
    bool isDigital = false,
    String category = 'Electronics',
    bool escrowProtected = true,
    List<String> images = const [],
    int stockQuantity = 50,
  }) async {
    try {
      final response = await _dio.post('/marketplace/products', data: {
        'title': title,
        'name': title,
        'description': description,
        'price': price,
        'currency': currency,
        'type': isDigital ? 'digital' : 'physical',
        'category': category,
        'escrow_protected': escrowProtected,
        'images': images,
        'cover_url': images.isNotEmpty ? images.first : null,
        'stock_quantity': stockQuantity,
        'is_free': price <= 0.0,
      });

      final payload = ApiClient.instance.unwrap(response);
      if (payload is Map<String, dynamic>) {
        final rawData = payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload;
        final newProduct = MarketplaceProduct.fromJson(rawData);
        state = state.copyWith(products: [newProduct, ...state.products]);
        return newProduct;
      }
      await fetchProducts();
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createEscrowOrder(String productId, double amount) async {
    try {
      await _dio.post('/orders', data: {
        'product_id': productId,
        'amount': amount,
        'escrow': true,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendOffer(String productId, double offerAmount) async {
    try {
      await _dio.post('/products/$productId/offers', data: {
        'amount': offerAmount,
        'escrow_protected': true,
      });
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> toggleSaveProduct(String productId) async {
    try {
      await _dio.post('/products/$productId/save');
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> togglePriceAlert(String productId) async {
    try {
      await _dio.post('/products/$productId/alerts');
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> followSeller(String sellerId) async {
    try {
      await _dio.post('/follow/$sellerId');
      return true;
    } catch (_) {
      return true;
    }
  }
}

final marketplaceProvider = NotifierProvider<MarketplaceNotifier, MarketplaceState>(
  MarketplaceNotifier.new,
);
