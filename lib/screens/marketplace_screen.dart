import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/marketplace_provider.dart';
import '../components/brand.dart';
import 'product_detail_screen.dart';

/// Facebook-Style Escrow Marketplace Screen with 2-column high-density image grid,
/// horizontal category chips, location picker modal, and Escrow protection flow.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _selectedMainCategory = 'Explore';
  String _selectedPhysicalSubCategory = 'All Physical';
  String _currentLocation = 'All Locations';
  final _searchController = TextEditingController();
  bool _isSearching = false;

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
        Offset pinPos = const Offset(160, 65);
        String tempLoc = _currentLocation;
        bool isEditing = false;
        final searchCtrl = TextEditingController();

        final allLocations = [
          'Lagos, Nigeria',
          'Ikeja, Lagos State',
          'Victoria Island, Lagos State',
          'Lekki, Lagos State',
          'Abuja, FCT',
          'Port Harcourt, Rivers State',
          'Ibadan, Oyo State',
          'Abeokuta, Ogun State',
          'London, United Kingdom',
          'New York, United States',
          'Toronto, Canada',
          'All Locations (Worldwide)',
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? const Color(0xFF3A3B3C) : Colors.white;

            final filteredLocations = allLocations.where((loc) {
              if (searchCtrl.text.trim().isEmpty) return true;
              return loc.toLowerCase().contains(searchCtrl.text.trim().toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
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

                      // Header Row with Title & Search Toggle Icon
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing ? 'Search Location' : 'Choose a Location',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                isEditing = !isEditing;
                              });
                            },
                            icon: Icon(
                              isEditing ? Icons.close_rounded : Icons.search_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isEditing) ...[
                        // Search / Custom Location Input
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Type city, state, or country…',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF007AFF)),
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                            // Tappable Map Canvas with Pin Placement
                            GestureDetector(
                              onTapDown: (details) {
                                final pos = details.localPosition;
                                setModalState(() {
                                  pinPos = pos;
                                  if (pos.dx < 100) {
                                    tempLoc = 'Ibadan, Oyo State';
                                  } else if (pos.dx < 200 && pos.dy < 70) {
                                    tempLoc = 'Ikeja, Lagos State';
                                  } else if (pos.dx < 200) {
                                    tempLoc = 'Lagos, Nigeria';
                                  } else if (pos.dx < 280) {
                                    tempLoc = 'Victoria Island, Lagos State';
                                  } else {
                                    tempLoc = 'Abuja, FCT';
                                  }
                                });
                              },
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  color: isDark ? const Color(0xFF1E3A2B) : const Color(0xFFCBE7C6),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          color: const Color(0xFF80BFFF).withOpacity(0.35),
                                          child: CustomPaint(
                                            painter: _MapPainter(isDark: isDark),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Tap map to set pin position',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      // Tapped Map Pin
                                      Positioned(
                                        left: pinPos.dx - 14,
                                        top: pinPos.dy - 28,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF007AFF),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF007AFF).withOpacity(0.6),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Color(0xFF007AFF), size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          tempLoc,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                          onPressed: () async {
                                            final allowed = await ref.read(permissionsProvider.notifier).ensureLocation(context);
                                            if (!allowed) return;
                                            setModalState(() {
                                              pinPos = const Offset(160, 65);
                                              tempLoc = 'Lagos, Nigeria';
                                            });
                                            setState(() {
                                              _currentLocation = 'Lagos, Nigeria';
                                            });
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Location updated to current GPS position (Lagos, Nigeria)')),
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
                                          onPressed: () {
                                            if (isEditing) {
                                              final input = searchCtrl.text.trim();
                                              if (input.isNotEmpty) {
                                                setState(() {
                                                  _currentLocation = input;
                                                });
                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Marketplace location changed to $input')),
                                                );
                                              }
                                            } else {
                                              setModalState(() {
                                                isEditing = true;
                                              });
                                            }
                                          },
                                          child: Text(isEditing ? 'Apply Custom' : 'Edit', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 16),

                      Text(
                        'Select City / Region',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredLocations.length,
                          itemBuilder: (ctx, idx) {
                            final locName = filteredLocations[idx];
                            final isSelected = locName == tempLoc || locName == _currentLocation;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF007AFF).withOpacity(0.15)
                                      : (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: isSelected ? const Color(0xFF007AFF) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                locName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF007AFF)
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 18)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _currentLocation = locName;
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Marketplace location set to $locName')),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
        child: Icon(Icons.location_on_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
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

  void _showMarketplaceOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Marketplace Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: Color(0xFF007AFF), size: 20),
                  ),
                  title: Text('Saved Items & Wishlist', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('View items you have saved or bookmarked', style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/app/saved');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF34C759), size: 20),
                  ),
                  title: Text('Create Listing / Sell Item', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('Post a physical or digital product to the marketplace', style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final user = ref.read(authProvider).user;
                    final role = user?.role ?? UserRole.member;
                    if (role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin) {
                      context.push('/app/create');
                    } else {
                      _showSellerUpgradeSheet();
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5856D6).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF5856D6), size: 20),
                  ),
                  title: Text('Escrow Wallet & Payouts', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('Manage earnings, held escrow funds & payout history', style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/wallet');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF9500), size: 20),
                  ),
                  title: Text('Filter by Location', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('Currently set to: $_currentLocation', style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLocationPickerModal();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.settings_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                  ),
                  title: Text('Store Settings', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('Configure seller preferences & shipping options', style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSellerUpgradeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF007AFF)),
              ),
              const SizedBox(height: 16),
              Text(
                'Become a Seller on MurihSpace',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Browsing and purchasing items is open to all users!\n\nTo list products and sell on Marketplace:\n• Upgrade to Creator to sell Digital Products.\n• Upgrade to Vendor to sell Physical Products & inventory.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/upgrade-account');
                },
                icon: const Icon(Icons.star_rounded),
                label: const Text('Upgrade to Creator (Digital Goods)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5856D6),
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF5856D6), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/upgrade-account');
                },
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Upgrade to Vendor (Physical Goods)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : const Color(0xFFF7FAFC);

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final role = user?.role ?? UserRole.member;

    final conversationsState = ref.watch(conversationsProvider);
    final unreadCount = conversationsState.unreadTotal;

    final marketState = ref.watch(marketplaceProvider);
    final allProducts = marketState.products;

    final allMarketItems = allProducts.map((p) {
      return _MarketItem(
        id: p.id,
        title: p.title,
        sellerName: p.sellerName,
        price: p.price,
        currencySymbol: p.symbol,
        imageUrl: p.images.isNotEmpty
            ? p.images.first
            : 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop',
        category: p.category,
        location: p.location,
        rating: p.sellerRating,
        isFree: p.isFree,
        escrowProtected: p.escrowProtected,
      );
    }).toList();

    final filteredItems = allMarketItems.where((item) {
      // Role-specific product isolation:
      if (role == UserRole.creator && item.category.toLowerCase() != 'digital') {
        return false;
      }
      if (role == UserRole.vendor && item.category.toLowerCase() == 'digital') {
        return false;
      }

      // Search filter
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final matchesQuery = item.title.toLowerCase().contains(q) ||
            item.sellerName.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.location.toLowerCase().contains(q);
        if (!matchesQuery) return false;
      }

      // Location filter
      if (_currentLocation != 'All Locations' && _currentLocation != 'Worldwide') {
        final city = _currentLocation.split(',').first.trim().toLowerCase();
        final itemLoc = item.location.toLowerCase();
        if (itemLoc != 'online delivery' && !itemLoc.contains(city)) {
          return false;
        }
      }

      // Category filter hierarchy
      if (_selectedMainCategory == 'Explore') {
        return true;
      } else if (_selectedMainCategory == 'Digital') {
        return item.category.toLowerCase() == 'digital' || item.category.toLowerCase().contains('digital') || item.category.toLowerCase().contains('template') || item.category.toLowerCase().contains('ebook');
      } else if (_selectedMainCategory == 'Physical') {
        if (item.category.toLowerCase() == 'digital') return false;
        if (_selectedPhysicalSubCategory == 'All Physical') return true;
        return item.category.toLowerCase() == _selectedPhysicalSubCategory.toLowerCase();
      }

      return true;
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
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
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
            onPressed: _showMarketplaceOptionsSheet,
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
          // Filter Bar with Saved Location FIRST, Divider |, and Main Categories (Explore, Digital, Physical)
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 1. Saved Location Chip (FIRST)
                ActionChip(
                  avatar: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF007AFF)),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentLocation,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF007AFF)),
                    ],
                  ),
                  backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: _showLocationPickerModal,
                ),

                // 2. Vertical Divider |
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Container(
                    width: 1.5,
                    height: 20,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                ),

                // 3. Main Category Chips (Explore, Digital, Physical)
                ...['Explore', 'Digital', 'Physical'].map((cat) {
                  final isSelected = cat == _selectedMainCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
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
                          setState(() {
                            _selectedMainCategory = cat;
                            if (cat != 'Physical') {
                              _selectedPhysicalSubCategory = 'All Physical';
                            }
                          });
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // 4. Secondary Physical Sub-Categories Row (Shown when Physical is active)
          if (_selectedMainCategory == 'Physical') ...[
            const SizedBox(height: 4),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All Physical', 'Property', 'Electronics', 'Vehicles', 'Fashion', 'Home'].map((subCat) {
                  final isSelected = subCat == _selectedPhysicalSubCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(subCat),
                      selected: isSelected,
                      selectedColor: const Color(0xFF5856D6).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF5856D6),
                      backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF5856D6)
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: isSelected ? const BorderSide(color: Color(0xFF5856D6), width: 1.5) : BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedPhysicalSubCategory = subCat;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // High-Density 2-Column Edge-to-Edge Product Grid (Facebook Style)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(marketplaceProvider.notifier).fetchProducts();
              },
              child: marketState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.storefront_outlined,
                                    size: 64,
                                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No products found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search query, location filter, or category.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMainCategory = 'Explore';
                                        _selectedPhysicalSubCategory = 'All Physical';
                                        _currentLocation = 'All Locations';
                                        _searchController.clear();
                                      });
                                      ref.read(marketplaceProvider.notifier).fetchProducts();
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Reset Filters'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                                : '${item.currencySymbol}${item.price >= 1000 ? (item.price / 1000).toStringAsFixed(item.price % 1000 == 0 ? 0 : 1) + 'k' : item.price.toStringAsFixed(0)} · ${item.title}',
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
