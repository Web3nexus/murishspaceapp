import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/gift_animation_overlay.dart';
import '../components/liquid_glass.dart';
import '../components/ui_states.dart';
import '../components/wallet_sheet.dart';
import '../core/api_client.dart';
import '../providers/gifts_provider.dart';
import '../providers/wallet_provider.dart';

/// Modern Liquid Glass Gift tray with a vertical-scrolling grid,
/// live currency conversion, category filter pills, and interactive send sheet.
class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key});

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  String _category = 'all';
  GiftItem? _selected;
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isAnonymous = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftsProvider.notifier).loadAll();
      ref.read(walletProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final gift = _selected;
    if (gift == null) return;
    final recipientId = int.tryParse(_recipientController.text.trim());
    if (recipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid recipient user ID.')),
      );
      return;
    }

    setState(() => _sending = true);
    final ok = await ref.read(giftsProvider.notifier).sendGift(
          giftId: gift.id,
          recipientId: recipientId,
          message: _messageController.text.trim(),
          isAnonymous: _isAnonymous,
        );

    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      // Play celebratory animation
      ref.read(giftAnimationProvider.notifier).play(
        GiftAnimationData(
          giftName: gift.name,
          iconUrl: ApiClient.resolveUrl(gift.iconUrl),
          coinPrice: gift.coinPrice,
          senderName: 'You',
          recipientName: 'User #$recipientId',
          animationType: gift.coinPrice >= 1000
              ? 'full_screen'
              : (gift.coinPrice >= 400 ? 'premium' : 'standard'),
        ),
      );

      // Refresh wallet after send
      ref.read(walletProvider.notifier).refresh();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully sent ${gift.name}!'),
          backgroundColor: const Color(0xFF34C759),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(giftsProvider).error ?? 'Failed to send gift.'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _openSendSheet(GiftItem gift) {
    setState(() => _selected = gift);
    _recipientController.clear();
    _messageController.clear();
    _isAnonymous = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark
            ? const Color(0xFF0F141C).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.6),
                    width: 1.5,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Consumer(
                builder: (ctx, ref, _) {
                  final walletCoins = ref.watch(walletProvider).coinsBalance;
                  final hasEnoughCoins = walletCoins >= gift.coinPrice;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Gift Hero Glass Card
                      LiquidGlassCard(
                        borderRadius: 20,
                        blurSigma: 12,
                        tintColor: const Color(0xFFFF9500),
                        isDark: isDark,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: (gift.iconUrl != null && gift.iconUrl!.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: ApiClient.resolveUrl(gift.iconUrl)!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.contain,
                                        placeholder: (_, _) => const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        errorWidget: (_, _, _) => const Icon(
                                          Icons.card_giftcard,
                                          color: Color(0xFFFF9500),
                                          size: 28,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.card_giftcard,
                                        color: Color(0xFFFF9500),
                                        size: 28,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gift.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        '🪙 ${gift.coinPrice} MSH',
                                        style: const TextStyle(
                                          color: Color(0xFFFF9500),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (gift.localFormatted != null &&
                                          gift.localFormatted!.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '· ≈ ${gift.localFormatted}',
                                          style: TextStyle(
                                            color: isDark ? Colors.white60 : Colors.black54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Creator receives: ${gift.creatorEarns} MSH',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black45,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Current Balance
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Your Balance',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$walletCoins MSH',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: hasEnoughCoins
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Insufficient Balance Warning Banner
                      if (!hasEnoughCoins) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFF9500), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Need ${(gift.coinPrice - walletCoins)} more coins to send this gift.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF9500),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  WalletSheet.show(context);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Top Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF007AFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Form Fields
                      TextField(
                        controller: _recipientController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Recipient User ID',
                          hintText: 'e.g. 104',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          filled: true,
                          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 2,
                        maxLength: 140,
                        decoration: InputDecoration(
                          labelText: 'Message (optional)',
                          hintText: 'Keep up the great work!',
                          prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
                          filled: true,
                          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Anonymous Toggle
                      Row(
                        children: [
                          Checkbox(
                            value: _isAnonymous,
                            activeColor: const Color(0xFF007AFF),
                            onChanged: (v) => setState(() => _isAnonymous = v ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                            child: Text(
                              'Send anonymously (hide sender identity)',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_sending || !hasEnoughCoins) ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
                            disabledForegroundColor: Colors.white38,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  hasEnoughCoins
                                      ? 'Send Gift (🪙 ${gift.coinPrice} MSH)'
                                      : 'Insufficient Coins',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(giftsProvider);
    final walletState = ref.watch(walletProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final coinsBalance = walletState.coinsBalance > 0
        ? walletState.coinsBalance
        : (state.wallet?.balance ?? 0);

    final categories = <String>{
      'all',
      ...state.gifts.map((g) => g.category),
    }.toList();

    final filteredGifts = state.gifts
        .where((g) => _category == 'all' || g.category == _category)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifts & Tipping', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: LiquidGlassPill(
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  WalletSheet.show(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '$coinsBalance MSH',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF9500),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.add_circle, size: 14, color: Color(0xFF007AFF)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(giftsProvider.notifier).loadAll();
          await ref.read(walletProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Liquid Glass Overview Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: LiquidGlassCard(
                  borderRadius: 22,
                  blurSigma: 18,
                  tintColor: const Color(0xFF007AFF),
                  isDark: isDark,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text('🎁', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reward & Elevate Creators',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '100 MSH = \$1.00 USD. Rate-synced to your local currency with zero inflation loss.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          WalletSheet.show(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get Coins',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Horizontal Category Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    final isSelected = _category == cat;
                    final formattedCat = cat[0].toUpperCase() + cat.substring(1);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF007AFF).withValues(alpha: isDark ? 0.35 : 0.15)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF007AFF)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08)),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            formattedCat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 14),
            ),

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AVAILABLE GIFTS (${filteredGifts.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Tap to send',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 10),
            ),

            // Content: Loading, Empty, or Downward-scrolling Vertical Grid
            if (state.loading && state.gifts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: LoadingStateWidget(message: 'Loading gifts…'),
                ),
              )
            else if (filteredGifts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyStateWidget(
                    icon: Icons.card_giftcard,
                    title: 'No gifts in this category',
                    description: 'Explore other categories or check back soon.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final gift = filteredGifts[i];
                      return _LiquidGlassGiftTile(
                        gift: gift,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openSendSheet(gift);
                        },
                      );
                    },
                    childCount: filteredGifts.length,
                  ),
                ),
              ),

            // Bottom padding for scroll clearance
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liquid Glass Gift Tile for the vertically scrolling grid
class _LiquidGlassGiftTile extends StatelessWidget {
  final GiftItem gift;
  final bool isDark;
  final VoidCallback onTap;

  const _LiquidGlassGiftTile({
    required this.gift,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiClient.resolveUrl(gift.iconUrl);

    return LiquidGlassCard(
      borderRadius: 18,
      blurSigma: 14,
      tintColor: const Color(0xFFFF9500),
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Artwork container
          Expanded(
            child: Center(
              child: (resolvedUrl != null && resolvedUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.card_giftcard,
                        size: 36,
                        color: Color(0xFFFF9500),
                      ),
                    )
                  : const Icon(
                      Icons.card_giftcard,
                      size: 36,
                      color: Color(0xFFFF9500),
                    ),
            ),
          ),
          const SizedBox(height: 6),

          // Gift Name
          Text(
            gift.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),

          // Coin Price
          Text(
            '🪙 ${gift.coinPrice} MSH',
            style: const TextStyle(
              color: Color(0xFFFF9500),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),

          // Local Currency Estimate (dynamic live conversion)
          if (gift.localFormatted != null && gift.localFormatted!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              '≈ ${gift.localFormatted}',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
