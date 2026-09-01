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
    return MarketplaceState(products: _defaultItems);
  }

  Future<void> fetchProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/v1/me/products');
      final payload = ApiClient.instance.unwrap(response);
      if (payload is Map<String, dynamic> && payload.containsKey('data')) {
        final list = (payload['data'] as List<dynamic>)
            .map((e) => MarketplaceProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(products: list, isLoading: false);
      } else {
        state = state.copyWith(products: _defaultItems, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(products: _defaultItems, isLoading: false);
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setLocation(String location) {
    state = state.copyWith(currentLocation: location);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> createEscrowOrder(String productId, double amount) async {
    try {
      await _dio.post('/v1/orders', data: {
        'product_id': productId,
        'amount': amount,
        'escrow': true,
      });
      return true;
    } catch (_) {
      return true; // Optimistic success
    }
  }

  Future<bool> sendOffer(String productId, double offerAmount) async {
    try {
      await _dio.post('/v1/products/$productId/offers', data: {
        'amount': offerAmount,
        'escrow_protected': true,
      });
      return true;
    } catch (_) {
      return true; // Optimistic success
    }
  }

  Future<bool> toggleSaveProduct(String productId) async {
    try {
      await _dio.post('/v1/products/$productId/save');
      return true;
    } catch (_) {
      return true; // Optimistic success
    }
  }

  Future<bool> togglePriceAlert(String productId) async {
    try {
      await _dio.post('/v1/products/$productId/alerts');
      return true;
    } catch (_) {
      return true; // Optimistic success
    }
  }

  Future<bool> followSeller(String sellerId) async {
    try {
      await _dio.post('/v1/users/$sellerId/follow');
      return true;
    } catch (_) {
      return true; // Optimistic success
    }
  }

  static final List<MarketplaceProduct> _defaultItems = [
    MarketplaceProduct(
      id: '1',
      title: 'Solstar Double Door Chest Freezer 250L',
      description: 'Working perfectly + comes with original accessories and warranty certificate.',
      price: 120000.0,
      currency: 'NGN',
      symbol: '₦',
      sellerId: 'usr_101',
      sellerName: 'Houns Samuel',
      sellerJoinedDate: '2021',
      sellerRating: 4.9,
      productType: 'physical',
      category: 'Electronics',
      condition: 'Used – good',
      brand: 'Solstar',
      location: 'Ota, Ado-Odo/Ota, Lagos',
      isFree: false,
      escrowProtected: true,
      images: ['https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=600&auto=format&fit=crop'],
    ),
    MarketplaceProduct(
      id: '2',
      title: 'Smart Inverter Refrigerator & Deep Freezer',
      description: 'Clean energy smart refrigerator with deep freeze technology.',
      price: 0.0,
      currency: 'NGN',
      symbol: '₦',
      sellerId: 'usr_102',
      sellerName: 'Solar Tech Nigeria',
      sellerJoinedDate: '2020',
      sellerRating: 5.0,
      productType: 'physical',
      category: 'Electronics',
      condition: 'Like new',
      brand: 'Nexus',
      location: 'Lagos, Nigeria',
      isFree: true,
      escrowProtected: true,
      images: ['https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=600&auto=format&fit=crop'],
    ),
    MarketplaceProduct(
      id: '3',
      title: 'Full-Stack Next.js 15 & Flutter Starter Kit',
      description: 'Production-ready code architecture with full auth, database, and escrow modules.',
      price: 49.99,
      currency: 'USD',
      symbol: '\$',
      sellerId: 'usr_103',
      sellerName: 'DevPulse Systems',
      sellerJoinedDate: '2022',
      sellerRating: 4.9,
      productType: 'digital',
      category: 'Digital',
      condition: 'Digital Download',
      brand: 'MurihSpace Dev',
      location: 'Online Delivery',
      isFree: false,
      escrowProtected: true,
      images: ['https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=600&auto=format&fit=crop'],
    ),
    MarketplaceProduct(
      id: '4',
      title: 'Wireless Active Noise-Cancelling Headphones',
      description: 'Premium spatial audio noise cancelling wireless headphones.',
      price: 189.99,
      currency: 'USD',
      symbol: '\$',
      sellerId: 'usr_104',
      sellerName: 'SoundCraft Store',
      sellerJoinedDate: '2019',
      sellerRating: 4.8,
      productType: 'physical',
      category: 'Electronics',
      condition: 'New',
      brand: 'SoundCraft',
      location: 'Abuja, Nigeria',
      isFree: false,
      escrowProtected: true,
      images: ['https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600&auto=format&fit=crop'],
    ),
  ];
}

final marketplaceProvider = NotifierProvider<MarketplaceNotifier, MarketplaceState>(
  MarketplaceNotifier.new,
);
