/// Data models for MurihSpace Marketplace products, seller specs, and Escrow orders.

class MarketplaceProduct {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String symbol;
  final String sellerId;
  final String sellerName;
  final String? sellerAvatar;
  final String sellerJoinedDate;
  final double sellerRating;
  final String productType; // 'physical' or 'digital'
  final String category;
  final String condition;
  final String brand;
  final String location;
  final bool isFree;
  final bool escrowProtected;
  final List<String> images;
  final Map<String, String> attributes;
  final DateTime createdAt;

  MarketplaceProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'USD',
    this.symbol = '\$',
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatar,
    this.sellerJoinedDate = '2021',
    this.sellerRating = 4.9,
    this.productType = 'physical',
    required this.category,
    this.condition = 'Used – good',
    this.brand = 'Nexus',
    required this.location,
    this.isFree = false,
    this.escrowProtected = true,
    required this.images,
    this.attributes = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    final currencyStr = json['currency'] as String? ?? 'USD';
    final symbolStr = currencyStr == 'NGN' ? '₦' : (currencyStr == 'EUR' ? '€' : (currencyStr == 'GBP' ? '£' : '\$'));
    final priceVal = (json['price'] as num?)?.toDouble() ?? 0.0;

    return MarketplaceProduct(
      id: json['id']?.toString() ?? '',
      title: json['name'] as String? ?? json['title'] as String? ?? 'Product Item',
      description: json['description'] as String? ?? '',
      price: priceVal,
      currency: currencyStr,
      symbol: symbolStr,
      sellerId: json['seller']?['id']?.toString() ?? json['user_id']?.toString() ?? 'usr_1',
      sellerName: json['seller']?['name'] as String? ?? json['seller_name'] as String? ?? 'Seller',
      sellerAvatar: json['seller']?['avatar_url'] as String? ?? json['seller_avatar'] as String?,
      sellerJoinedDate: json['seller_joined'] as String? ?? '2021',
      sellerRating: (json['seller_rating'] as num?)?.toDouble() ?? 4.9,
      productType: json['product_type'] as String? ?? json['type'] as String? ?? 'physical',
      category: json['category'] as String? ?? 'General',
      condition: json['condition'] as String? ?? 'Used – good',
      brand: json['brand'] as String? ?? 'Standard',
      location: json['location'] as String? ?? 'Lagos, Nigeria',
      isFree: priceVal == 0.0,
      escrowProtected: json['escrow_protected'] as bool? ?? true,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [json['thumbnail'] as String? ?? ''],
      attributes: (json['attributes'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': title,
        'description': description,
        'price': price,
        'currency': currency,
        'seller': {'id': sellerId, 'name': sellerName, 'avatar_url': sellerAvatar},
        'product_type': productType,
        'category': category,
        'condition': condition,
        'brand': brand,
        'location': location,
        'escrow_protected': escrowProtected,
        'images': images,
        'attributes': attributes,
        'created_at': createdAt.toIso8601String(),
      };
}

class EscrowOrder {
  final String id;
  final String productId;
  final String productTitle;
  final double amount;
  final String currency;
  final String symbol;
  final String buyerId;
  final String sellerId;
  final String status; // 'locked', 'released', 'disputed', 'cancelled'
  final DateTime lockedAt;
  final DateTime? releasedAt;

  EscrowOrder({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.amount,
    required this.currency,
    required this.symbol,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.lockedAt,
    this.releasedAt,
  });

  factory EscrowOrder.fromJson(Map<String, dynamic> json) {
    final curr = json['currency'] as String? ?? 'USD';
    final sym = curr == 'NGN' ? '₦' : (curr == 'EUR' ? '€' : (curr == 'GBP' ? '£' : '\$'));
    return EscrowOrder(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productTitle: json['product_title'] as String? ?? 'Order Item',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: curr,
      symbol: sym,
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      status: json['status'] as String? ?? 'locked',
      lockedAt: json['locked_at'] != null ? DateTime.parse(json['locked_at'] as String) : DateTime.now(),
      releasedAt: json['released_at'] != null ? DateTime.parse(json['released_at'] as String) : null,
    );
  }
}
