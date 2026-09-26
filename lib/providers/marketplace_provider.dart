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
    Future.microtask(() => fetchProducts());
    return MarketplaceState(
      isLoading: true,
      products: defaultMarketplaceProducts,
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
        products: list.isNotEmpty ? list : state.products,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        products: state.products.isNotEmpty ? state.products : defaultMarketplaceProducts,
        isLoading: false,
        error: 'Unable to load products. Pull down to refresh.',
      );
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
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

final List<MarketplaceProduct> defaultMarketplaceProducts = [
  MarketplaceProduct(
    id: '1',
    title: 'Solstar Double Door Chest Freezer 250L',
    description: 'High-efficiency fast cooling inverter double door freezer with 2 years warranty.',
    price: 120000.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '101',
    sellerName: 'Dele Electronics',
    sellerRating: 4.9,
    category: 'Electronics',
    condition: 'Brand new',
    brand: 'Solstar',
    location: 'Lagos, Nigeria',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '2',
    title: 'Smart Inverter Refrigerator & Deep Freezer',
    description: 'Energy saving refrigerator, low power consumption, ideal for solar or inverter systems.',
    price: 0.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '102',
    sellerName: 'Solar Tech Nigeria',
    sellerRating: 5.0,
    category: 'Electronics',
    condition: 'Brand new',
    brand: 'SolarTech',
    location: 'Lagos, Nigeria',
    isFree: true,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '3',
    title: 'Full-Stack Next.js 15 & Flutter Starter Kit',
    description: 'Production-ready production kit with auth, payments, chat, and admin dashboard templates.',
    price: 49.99,
    currency: 'USD',
    symbol: '\$',
    sellerId: '103',
    sellerName: 'DevPulse Systems',
    sellerRating: 4.9,
    productType: 'digital',
    category: 'Digital',
    condition: 'Digital Asset',
    brand: 'DevPulse',
    location: 'Online Delivery',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '4',
    title: 'Apple MacBook Pro M3 Max 16-inch (36GB / 1TB)',
    description: 'Space Black, pristine battery health 100%, original 140W charger, Box and receipt included.',
    price: 2850000.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '104',
    sellerName: 'Apple Hub Ikeja',
    sellerRating: 5.0,
    category: 'Electronics',
    condition: 'Used – like new',
    brand: 'Apple',
    location: 'Ikeja, Lagos State',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '5',
    title: 'Modern Ergonomic Mesh Office Chair with Lumbar Support',
    description: 'Adjustable headrest and 3D armrests, breathable mesh fabric, heavy-duty chrome base.',
    price: 95000.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '105',
    sellerName: 'WorkSpace Living',
    sellerRating: 4.8,
    category: 'Home',
    condition: 'Brand new',
    brand: 'ErgoComfort',
    location: 'Victoria Island, Lagos State',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1580481077111-534a6efc4ff8?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '6',
    title: 'SaaS Boilerplate & Multi-Tenant API Framework',
    description: 'Turnkey Laravel 11 + React boilerplate with multi-tenancy, Stripe/Paystack billing, and roles.',
    price: 89.0,
    currency: 'USD',
    symbol: '\$',
    sellerId: '106',
    sellerName: 'CloudForge Labs',
    sellerRating: 5.0,
    productType: 'digital',
    category: 'Digital',
    condition: 'Digital Asset',
    brand: 'CloudForge',
    location: 'Online Delivery',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '7',
    title: 'Toyota Camry 2021 XSE V6 (Foreign Used)',
    description: 'Custom red leather interior, panoramic sunroof, JBL premium sound system, clean carfax.',
    price: 24500000.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '107',
    sellerName: 'Lekki Auto Vault',
    sellerRating: 4.9,
    category: 'Vehicles',
    condition: 'Used – like new',
    brand: 'Toyota',
    location: 'Lekki, Lagos State',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=600&auto=format&fit=crop',
    ],
  ),
  MarketplaceProduct(
    id: '8',
    title: 'Luxury 4-Bedroom Semi-Detached Duplex with BQ',
    description: 'Fully serviced estate, 24/7 power, treated water plant, fitted kitchen, stamped concrete floor.',
    price: 135000000.0,
    currency: 'NGN',
    symbol: '₦',
    sellerId: '108',
    sellerName: 'Prime Crest Properties',
    sellerRating: 5.0,
    category: 'Property',
    condition: 'Brand new',
    brand: 'PrimeCrest',
    location: 'Lekki, Lagos State',
    isFree: false,
    escrowProtected: true,
    images: const [
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=600&auto=format&fit=crop',
    ],
  ),
];

