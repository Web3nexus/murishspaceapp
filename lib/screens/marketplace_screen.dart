import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import 'product_detail_screen.dart';

/// Facebook-Style Escrow Marketplace Screen with 2-column high-density image grid,
/// horizontal category chips, location picker modal, and Escrow protection flow.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _selectedCategory = 'Explore';
  String _currentLocation = 'Lagos, Nigeria';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _categories = [
    'Sell',
    'Explore',
    'Local',
    'Categories',
    'Electronics',
    'Vehicles',
    'Property',
    'Digital',
  ];

  final List<_MarketItem> _allItems = [
    _MarketItem(
      id: '1',
      title: 'Solstar Double Door Chest Freezer 250L',
      sellerName: 'Dele Electronics',
      price: 120000.0,
      currencySymbol: '₦',
      imageUrl: 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=600&auto=format&fit=crop',
      category: 'Electronics',
      location: 'Lagos, Nigeria',
      rating: 4.9,
      isFree: false,
      escrowProtected: true,
    ),
    _MarketItem(
      id: '2',
      title: 'Smart Inverter Refrigerator & Deep Freezer',
      sellerName: 'Solar Tech Nigeria',
      price: 0.0,
      currencySymbol: '₦',
      imageUrl: 'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=600&auto=format&fit=crop',
      category: 'Electronics',
      location: 'Lagos, Nigeria',
      rating: 5.0,
      isFree: true,
      escrowProtected: true,
    ),
    _MarketItem(
      id: '3',
      title: 'Full-Stack Next.js 15 & Flutter Starter Kit',
      sellerName: 'DevPulse Systems',
      price: 49.99,
      currencySymbol: '\$',
      imageUrl: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=600&auto=format&fit=crop',
      category: 'Digital',
      location: 'Online Delivery',
      rating: 4.9,
      isFree: false,
      escrowProtected: true,
    ),
    _MarketItem(
      id: '4',
      title: 'Wireless Active Noise-Cancelling Headphones',
      sellerName: 'SoundCraft Store',
      price: 189.99,
      currencySymbol: '\$',
      imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600&auto=format&fit=crop',
      category: 'Electronics',
      location: 'Abuja, Nigeria',
      rating: 4.8,
      isFree: false,
      escrowProtected: true,
    ),
    _MarketItem(
      id: '5',
      title: 'Ergonomic Desk & Mechanical RGB Keyboard',
      sellerName: 'Workspace Outfitters',
      price: 129.50,
      currencySymbol: '\$',
      imageUrl: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=600&auto=format&fit=crop',
      category: 'Electronics',
      location: 'Ibadan, Nigeria',
      rating: 4.7,
      isFree: false,
      escrowProtected: true,
    ),
    _MarketItem(
      id: '6',
      title: 'UI/UX Pro Design System & Figma Tokens',
      sellerName: 'Creative Studio',
      price: 29.00,
      currencySymbol: '\$',
      imageUrl: 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=600&auto=format&fit=crop',
      category: 'Digital',
      location: 'Online Delivery',
      rating: 4.9,
      isFree: false,
      escrowProtected: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLocationPickerModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242526)
          : const Color(0xFFF0F2F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF3A3B3C) : Colors.white;

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag indicator handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header Row with Title & Search Icon
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a location',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Icon(Icons.search_rounded, color: isDark ? Colors.white : Colors.black, size: 24),
                  ],
                ),
                const SizedBox(height: 16),

                // Interactive Map Preview Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simulated Map View Graphics
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A2B) : const Color(0xFFCBE7C6),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF80BFFF).withOpacity(0.4),
                                child: CustomPaint(
                                  painter: _MapPainter(isDark: isDark),
                                ),
                              ),
                            ),
                            // Map Pin Dot
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF007AFF).withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentLocation,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Location updated to current GPS position')),
                                      );
                                    },
                                    icon: const Icon(Icons.near_me_rounded, size: 18),
                                    label: const Text('Locate me', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? const Color(0xFF4E4F50) : const Color(0xFFE4E6EB),
                                      foregroundColor: isDark ? Colors.white : Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Suggested Locations Header
                Text(
                  'Suggested for you',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                // Location List Items
                _locationTile(ctx, 'Ibadan, Oyo State', isDark),
                _locationTile(ctx, 'Abeokuta, Ogun State', isDark),
                _locationTile(ctx, 'Ijebu Ode, Ogun State', isDark),
                _locationTile(ctx, 'Port Harcourt, Rivers State', isDark),
                _locationTile(ctx, 'Abuja, FCT', isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _locationTile(BuildContext ctx, String locationName, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.search_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
      ),
      title: Text(
        locationName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      onTap: () {
        setState(() => _currentLocation = locationName);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marketplace location changed to $locationName')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : const Color(0xFFF7FAFC);

    final filteredItems = _allItems.where((item) {
      if (_selectedCategory == 'Explore') return true;
      if (_selectedCategory == 'Local') return item.location.contains(_currentLocation.split(',').first);
      if (_selectedCategory == 'Sell') return true;
      return item.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search Marketplace…',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                'Marketplace',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),
        actions: [
          IconButton(
            onPressed: () {
              final shell = StatefulNavigationShell.of(context);
              shell.goBranch(1);
            },
            icon: Stack(
              children: [
                BrandFavicon(
                  size: 24,
                  isDark: isDark,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '6',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'Messenger',
          ),
          IconButton(
            onPressed: () => setState(() => _isSearching = !_isSearching),
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marketplace menu: Saved Items, Listings & Inbox')),
              );
            },
            icon: Icon(
              Icons.more_horiz_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 26,
            ),
            tooltip: 'Options',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-Header Categories & Location Horizontal Scroll Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _categories.length) {
                  // Location Selector Button Tile
                  return ActionChip(
                    avatar: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF007AFF)),
                    label: Text(
                      _currentLocation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: _showLocationPickerModal,
                  );
                }

                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;

                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cat == 'Sell') ...[
                        const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(cat),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF007AFF),
                  backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (val) {
                    if (val) {
                      if (cat == 'Local') {
                        _showLocationPickerModal();
                      }
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // High-Density 2-Column Edge-to-Edge Product Grid (Facebook Style)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          itemData: {
                            'id': item.id,
                            'title': item.title,
                            'sellerName': item.sellerName,
                            'price': item.price,
                            'currencySymbol': item.currencySymbol,
                            'imageUrl': item.imageUrl,
                            'category': item.category,
                            'location': item.location,
                            'rating': item.rating,
                            'isFree': item.isFree,
                            'escrowProtected': item.escrowProtected,
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242526) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Image Container
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                  ),
                                ),
                              ),
                              // Escrow Shield Badge Overlay
                              if (item.escrowProtected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_rounded, color: Color(0xFF34C759), size: 12),
                                        SizedBox(width: 3),
                                        Text(
                                          'Escrow',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Title & Price Overlay Info (Facebook Marketplace Style)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.isFree
                                    ? 'Free · ${item.title}'
                                    : '${item.currencySymbol}${item.price > 1000 ? (item.price / 1000).toStringAsFixed(0) + 'k' : item.price.toStringAsFixed(0)} · ${item.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.location} · ★${item.rating}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketItem {
  final String id;
  final String title;
  final String sellerName;
  final double price;
  final String currencySymbol;
  final String imageUrl;
  final String category;
  final String location;
  final double rating;
  final bool isFree;
  final bool escrowProtected;

  _MarketItem({
    required this.id,
    required this.title,
    required this.sellerName,
    required this.price,
    required this.currencySymbol,
    required this.imageUrl,
    required this.category,
    required this.location,
    required this.rating,
    required this.isFree,
    required this.escrowProtected,
  });
}

class _MapPainter extends CustomPainter {
  final bool isDark;

  _MapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF2C4C38) : const Color(0xFF9FD3A7)
      ..style = PaintingStyle.fill;

    // Draw Land Masses
    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width * 0.8, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.6, size.width, size.height * 0.3);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
