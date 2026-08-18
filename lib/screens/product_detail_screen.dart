import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import '../providers/marketplace_provider.dart';

/// Facebook-Style Product Details Screen with Seller DM bar, Quick Actions (Alerts, Send Offer, Share, Save),
/// Escrow Protection Guarantee, Seller Profile card, Specs Details table, Location Map, and Buy with Escrow CTA.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;

  const ProductDetailScreen({super.key, required this.itemData});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _messageController = TextEditingController(text: 'Hi, is this available?');
  bool _isSaved = false;
  bool _isFollowingSeller = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessageToSeller() async {
    final sellerIdStr = widget.itemData['sellerId'] as String? ?? '101';
    final sellerId = int.tryParse(sellerIdStr) ?? sellerIdStr.hashCode.abs();
    final sellerName = widget.itemData['sellerName'] as String? ?? 'Seller';
    final title = widget.itemData['title'] as String? ?? 'Product Item';
    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    final conversation = await ref.read(conversationsProvider.notifier).openDirectChat(
          sellerId,
          name: sellerName,
          username: sellerName.toLowerCase().replaceAll(' ', '_'),
        );

    if (conversation != null && mounted) {
      context.push('/app/conversation/${conversation.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat opened with $sellerName for "$title"'),
          backgroundColor: const Color(0xFF007AFF),
        ),
      );
    }
  }

  void _shareProduct() {
    final title = widget.itemData['title'] as String? ?? 'Product';
    final id = widget.itemData['id'] as String? ?? '1';
    final link = 'https://murihspace.com/marketplace/product/$id';

    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product link for "$title" copied to clipboard!'),
        backgroundColor: const Color(0xFF007AFF),
      ),
    );
  }

  void _toggleSave() {
    final id = widget.itemData['id'] as String? ?? '1';
    setState(() => _isSaved = !_isSaved);
    ref.read(marketplaceProvider.notifier).toggleSaveProduct(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Item saved to your Wishlist!' : 'Item removed from Wishlist.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleFollowSeller() {
    final sellerId = widget.itemData['sellerId'] as String? ?? 'usr_101';
    setState(() => _isFollowingSeller = !_isFollowingSeller);
    ref.read(marketplaceProvider.notifier).followSeller(sellerId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFollowingSeller ? 'Now following seller!' : 'Unfollowed seller.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSendOfferModal() {
    final productId = widget.itemData['id'] as String? ?? '1';
    final price = widget.itemData['price'] as double? ?? 0.0;
    final symbol = widget.itemData['currencySymbol'] as String? ?? '\$';
    final sellerIdStr = widget.itemData['sellerId'] as String? ?? '101';
    final sellerId = int.tryParse(sellerIdStr) ?? sellerIdStr.hashCode.abs();
    final sellerName = widget.itemData['sellerName'] as String? ?? 'Seller';
    final offerController = TextEditingController(text: (price * 0.9).toStringAsFixed(2));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242526)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Make an Offer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Asking price: $symbol${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: offerController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  prefixText: '$symbol ',
                  labelText: 'Your offer price',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final offerVal = double.tryParse(offerController.text.trim()) ?? (price * 0.9);
                    await ref.read(marketplaceProvider.notifier).sendOffer(productId, offerVal);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Offer of $symbol${offerVal.toStringAsFixed(2)} submitted with Escrow protection!'),
                        ),
                      );
                      final conversation = await ref.read(conversationsProvider.notifier).openDirectChat(
                            sellerId,
                            name: sellerName,
                            username: sellerName.toLowerCase().replaceAll(' ', '_'),
                          );
                      if (conversation != null && mounted) {
                        context.push('/app/conversation/${conversation.id}');
                      }
                    }
                  },
                  child: const Text('Send Offer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBuyEscrowModal() {
    final productId = widget.itemData['id'] as String? ?? '1';
    final title = widget.itemData['title'] as String? ?? 'Product Item';
    final price = widget.itemData['price'] as double? ?? 0.0;
    final symbol = widget.itemData['currencySymbol'] as String? ?? '\$';
    final isFree = widget.itemData['isFree'] as bool? ?? false;
    final sellerIdStr = widget.itemData['sellerId'] as String? ?? '101';
    final sellerId = int.tryParse(sellerIdStr) ?? sellerIdStr.hashCode.abs();
    final sellerName = widget.itemData['sellerName'] as String? ?? 'Seller';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFF34C759), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Escrow Protected Checkout',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            'Funds held safely in escrow until delivery is confirmed',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Text(
                            isFree ? 'Free' : '$symbol${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Seller: $sellerName',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await ref.read(marketplaceProvider.notifier).createEscrowOrder(productId, price);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Order confirmed! $symbol${price.toStringAsFixed(2)} locked safely in Escrow.',
                            ),
                          ),
                        );
                        final conversation = await ref.read(conversationsProvider.notifier).openDirectChat(
                              sellerId,
                              name: sellerName,
                              username: sellerName.toLowerCase().replaceAll(' ', '_'),
                            );
                        if (conversation != null && mounted) {
                          context.push('/app/conversation/${conversation.id}');
                        }
                      }
                    },
                    child: const Text(
                      'Confirm Escrow Payment',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final title = widget.itemData['title'] as String? ?? 'Product Item';
    final price = widget.itemData['price'] as double? ?? 0.0;
    final symbol = widget.itemData['currencySymbol'] as String? ?? '\$';
    final imageUrl = widget.itemData['imageUrl'] as String? ?? '';
    final sellerName = widget.itemData['sellerName'] as String? ?? 'Houns Samuel';
    final location = widget.itemData['location'] as String? ?? 'Ota, Ado-Odo/Ota, Lagos';
    final isFree = widget.itemData['isFree'] as bool? ?? false;
    final category = widget.itemData['category'] as String? ?? 'Electronics';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textPrimary, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: textPrimary, size: 24),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: textPrimary, size: 26),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Container
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                              child: const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            ),
                          ),
                        ),
                        // Escrow Shield Badge Top Overlay
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, color: Color(0xFF34C759), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'ESCROW PROTECTED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Price
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFree ? 'Free' : '$symbol${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Listed in $location · Category: $category',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                        const SizedBox(height: 16),

                        // Inline "Message Seller" Quick Input Bar (Facebook Style)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.chat_bubble_rounded, color: Color(0xFF007AFF), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Message seller',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3A3B3C) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: TextField(
                                        controller: _messageController,
                                        style: TextStyle(fontSize: 14, color: textPrimary),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    ),
                                    onPressed: _sendMessageToSeller,
                                    child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Quick Action Buttons Row: Alerts, Send Offer, Share, Save
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _actionCircleButton(
                              icon: Icons.notifications_none_rounded,
                              label: 'Alerts',
                              isDark: isDark,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Alerts set for similar items')),
                                );
                              },
                            ),
                            _actionCircleButton(
                              icon: Icons.handshake_outlined,
                              label: 'Send offer',
                              isDark: isDark,
                              onTap: _showSendOfferModal,
                            ),
                            _actionCircleButton(
                              icon: Icons.shortcut_rounded,
                              label: 'Share',
                              isDark: isDark,
                              onTap: _shareProduct,
                            ),
                            _actionCircleButton(
                              icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              label: 'Save',
                              isDark: isDark,
                              active: _isSaved,
                              onTap: _toggleSave,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                        const SizedBox(height: 16),

                        // Description Section
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Working perfectly + comes with original accessories and warranty certificate.\n\nCall / WhatsApp seller via MurihSpace Messenger.',
                          style: TextStyle(fontSize: 14, height: 1.4, color: textPrimary),
                        ),
                        const SizedBox(height: 20),
                        Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                        const SizedBox(height: 16),

                        // Seller Card Section ("Seller >")
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Seller',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: textSecondary),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF007AFF),
                              child: Text(
                                sellerName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sellerName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Joined MurihSpace in 2021 · Active seller · ★ 4.9',
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowingSeller
                                    ? (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB))
                                    : const Color(0xFF007AFF),
                                foregroundColor: _isFollowingSeller
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _toggleFollowSeller,
                              child: Text(
                                _isFollowingSeller ? 'Following' : 'Follow',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                        const SizedBox(height: 16),

                        // Details Table Section
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _detailRow('Condition', 'Used – good', isDark),
                        _detailRow('Brand', 'Nexus / Solstar', isDark),
                        _detailRow('Escrow Status', 'Protected by MurihSpace', isDark),
                        const SizedBox(height: 20),
                        Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                        const SizedBox(height: 16),

                        // Location Card Section
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Map graphics container
                              Container(
                                height: 110,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E3A2B) : const Color(0xFFCBE7C6),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF007AFF), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          location,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Location is approximate',
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                        foregroundColor: isDark ? Colors.white : Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {},
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      label: const Text('Mark as too far', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar: Buy with Escrow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242526) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showBuyEscrowModal,
                  icon: const Icon(Icons.shield_rounded, size: 20),
                  label: Text(
                    isFree ? 'Claim Free Item with Escrow' : 'Buy with Escrow · $symbol${price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCircleButton({
    required IconData icon,
    required String label,
    required bool isDark,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final iconColor = active ? const Color(0xFF007AFF) : (isDark ? Colors.white : Colors.black);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
