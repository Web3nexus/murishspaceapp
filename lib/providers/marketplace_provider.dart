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

  /// The signed-in user's own catalog (creator/vendor products) shown in the
  /// ads manager catalog view — never seeded from hardcoded data.
  final List<MarketplaceProduct> myProducts;
  final bool myProductsLoading;
  final String? myProductsError;

  MarketplaceState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = 'Explore',
    this.currentLocation = 'Lagos, Nigeria',
    this.searchQuery = '',
    this.myProducts = const [],
    this.myProductsLoading = false,
    this.myProductsError,
  });

  MarketplaceState copyWith({
    List<MarketplaceProduct>? products,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? currentLocation,
    String? searchQuery,
    List<MarketplaceProduct>? myProducts,
    bool? myProductsLoading,
    String? myProductsError,
  }) {
    return MarketplaceState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      currentLocation: currentLocation ?? this.currentLocation,
      searchQuery: searchQuery ?? this.searchQuery,
      myProducts: myProducts ?? this.myProducts,
      myProductsLoading: myProductsLoading ?? this.myProductsLoading,
      myProductsError: myProductsError,
    );
  }
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  MarketplaceState build() {
    Future.microtask(() => fetchProducts());
    return MarketplaceState(
      isLoading: true,
    );
  }

  Future<void> fetchProducts() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

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
      } else if (payload is Map) {
        final dataField = payload['data'];
        if (dataField is List) {
          listRaw = dataField;
        } else if (dataField is Map && dataField['data'] is List) {
          listRaw = dataField['data'] as List<dynamic>;
        }
      }

      final list = <MarketplaceProduct>[];
      for (final e in listRaw) {
        if (e is Map) {
          try {
            list.add(MarketplaceProduct.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }

      state = state.copyWith(
        products: list,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load products. Pull down to refresh.',
      );
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Loads the signed-in user's own catalog products from
  /// GET /marketplace/my/products — the single source for "my catalog" in
  /// the ads manager. Falls back to an empty list, never fake data.
  Future<void> fetchMyProducts() async {
    try {
      state = state.copyWith(myProductsLoading: true, myProductsError: null);

      final response = await _dio.get('/marketplace/my/products');
      final payload = ApiClient.instance.unwrap(response);
      List<dynamic> listRaw = [];
      if (payload is List) {
        listRaw = payload;
      } else if (payload is Map && payload['data'] is List) {
        listRaw = payload['data'] as List<dynamic>;
      }

      final list = <MarketplaceProduct>[];
      for (final e in listRaw) {
        if (e is Map) {
          try {
            list.add(MarketplaceProduct.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }

      state = state.copyWith(
        myProducts: list,
        myProductsLoading: false,
        myProductsError: null,
      );
    } catch (e) {
      state = state.copyWith(
        myProductsLoading: false,
        myProductsError: 'Unable to load your catalog.',
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
      return false;
    }
  }

  Future<bool> toggleSaveProduct(String productId) async {
    try {
      await _dio.post('/products/$productId/save');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> togglePriceAlert(String productId) async {
    try {
      await _dio.post('/products/$productId/alerts');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> followSeller(String sellerId) async {
    try {
      await _dio.post('/follow/$sellerId');
      return true;
    } catch (_) {
      return false;
    }
  }
}

final marketplaceProvider = NotifierProvider<MarketplaceNotifier, MarketplaceState>(
  MarketplaceNotifier.new,
);

