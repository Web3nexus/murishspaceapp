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
    final currencyStr = json['currency']?.toString() ?? 'USD';
    final symbolStr = json['symbol']?.toString() ??
        (currencyStr == 'NGN'
            ? '₦'
            : (currencyStr == 'EUR'
                ? '€'
                : (currencyStr == 'GBP' ? '£' : '\$')));

    final rawPrice = json['price'];
    final priceVal = rawPrice is num
        ? rawPrice.toDouble()
        : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0);

    List<String> imageList = [];
    if (json['images'] is List) {
      for (final e in (json['images'] as List)) {
        if (e != null && e.toString().trim().isNotEmpty) {
          imageList.add(e.toString().trim());
        }
      }
    }
    if (imageList.isEmpty) {
      if (json['cover_url'] != null && json['cover_url'].toString().trim().isNotEmpty) {
        imageList.add(json['cover_url'].toString().trim());
      } else if (json['thumbnail'] != null && json['thumbnail'].toString().trim().isNotEmpty) {
        imageList.add(json['thumbnail'].toString().trim());
      }
    }
    if (imageList.isEmpty) {
      imageList = ['https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop'];
    }

    final creator = json['creator'] is Map ? (json['creator'] as Map).cast<String, dynamic>() : null;
    final seller = json['seller'] is Map ? (json['seller'] as Map).cast<String, dynamic>() : null;

    final sId = json['sellerId']?.toString() ??
        seller?['id']?.toString() ??
        creator?['id']?.toString() ??
        json['creator_id']?.toString() ??
        json['user_id']?.toString() ??
        '1';

    final sName = json['sellerName']?.toString() ??
        seller?['name']?.toString() ??
        creator?['name']?.toString() ??
        json['seller_name']?.toString() ??
        'Creator';

    final sAvatar = json['sellerAvatar']?.toString() ??
        seller?['avatar_url']?.toString() ??
        seller?['avatar']?.toString() ??
        creator?['avatar_url']?.toString() ??
        creator?['avatar']?.toString() ??
        json['seller_avatar']?.toString();

    String sJoined = '2024';
    if (json['sellerJoinedDate'] != null && json['sellerJoinedDate'].toString().isNotEmpty) {
      sJoined = json['sellerJoinedDate'].toString();
    } else if (json['seller_joined'] != null && json['seller_joined'].toString().isNotEmpty) {
      sJoined = json['seller_joined'].toString();
    } else if (creator?['created_at'] != null) {
      final cAt = creator!['created_at'].toString();
      sJoined = cAt.length >= 4 ? cAt.substring(0, 4) : '2024';
    }

    final rawRating = json['sellerRating'] ?? json['seller_rating'] ?? json['rating'];
    final ratingVal = rawRating is num
        ? rawRating.toDouble()
        : (double.tryParse(rawRating?.toString() ?? '4.9') ?? 4.9);

    bool parseBool(dynamic val, [bool fallback = false]) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final s = val.toLowerCase().trim();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return fallback;
    }

    final isFreeVal = parseBool(json['is_free'], priceVal <= 0.0);
    final escrowVal = parseBool(json['escrow_protected'], true);

    Map<String, String> attrMap = {};
    if (json['attributes'] is Map) {
      attrMap = (json['attributes'] as Map).map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    }

    final pType = json['product_type']?.toString() ?? json['type']?.toString() ?? 'physical';

    DateTime createdAtDate = DateTime.now();
    if (json['created_at'] != null) {
      createdAtDate = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    return MarketplaceProduct(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Product Item',
      description: json['description']?.toString() ?? '',
      price: priceVal,
      currency: currencyStr,
      symbol: symbolStr,
      sellerId: sId,
      sellerName: sName,
      sellerAvatar: sAvatar,
      sellerJoinedDate: sJoined,
      sellerRating: ratingVal,
      productType: pType,
      category: json['category']?.toString() ?? (pType == 'digital' ? 'Digital' : 'General'),
      condition: json['condition']?.toString() ?? (pType == 'digital' ? 'Digital Asset' : 'Brand new'),
      brand: json['brand']?.toString() ?? 'MurihSpace',
      location: json['location']?.toString() ?? (pType == 'digital' ? 'Online Delivery' : 'Global'),
      isFree: isFreeVal,
      escrowProtected: escrowVal,
      images: imageList,
      attributes: attrMap,
      createdAt: createdAtDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'price': price,
        'currencySymbol': symbol,
        'sellerName': sellerName,
        'sellerAvatar': sellerAvatar,
        'sellerJoinedDate': sellerJoinedDate,
        'rating': sellerRating,
        'productType': productType,
        'category': category,
        'condition': condition,
        'brand': brand,
        'location': location,
        'isFree': isFree,
        'escrowProtected': escrowProtected,
        'images': images,
        'attributes': attributes,
        'created_at': createdAt.toIso8601String(),
      };
}

class MarketplaceEscrow {
  final String orderId;
  final String productTitle;
  final double amount;
  final String symbol;
  final String buyerId;
  final String sellerId;
  final String status;
  final DateTime lockedAt;
  final DateTime? releasedAt;

  MarketplaceEscrow({
    required this.orderId,
    required this.productTitle,
    required this.amount,
    required this.symbol,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.lockedAt,
    this.releasedAt,
  });

  factory MarketplaceEscrow.fromJson(Map<String, dynamic> json) {
    final curr = json['currency']?.toString() ?? 'USD';
    final sym = curr == 'NGN' ? '₦' : '\$';
    final rawAmount = json['amount'];
    final amountVal = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0);
    return MarketplaceEscrow(
      orderId: json['order_id']?.toString() ?? json['id']?.toString() ?? 'ORD-101',
      productTitle: json['product_title']?.toString() ?? 'Order Item',
      amount: amountVal,
      symbol: sym,
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'locked',
      lockedAt: json['locked_at'] != null ? (DateTime.tryParse(json['locked_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      releasedAt: json['released_at'] != null ? DateTime.tryParse(json['released_at'].toString()) : null,
    );
  }
}
