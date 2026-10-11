import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gifts_provider.dart';
import '../providers/wallet_provider.dart';
import 'brand.dart';

/// Bottom sheet for buying MSH Coins matching the MurihPay design system.
/// Displays user coin balance, package selector with bonuses and popular badges,
/// and instant purchase execution with optimistic updates.
class BuyCoinsSheet extends ConsumerStatefulWidget {
  const BuyCoinsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BuyCoinsSheet(),
    );
  }

  @override
  ConsumerState<BuyCoinsSheet> createState() => _BuyCoinsSheetState();
}

class _BuyCoinsSheetState extends ConsumerState<BuyCoinsSheet> {
  CoinPack? _selectedPack;
  bool _isPurchasing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftsProvider.notifier).loadAll();
    });
  }

  Future<void> _handlePurchase(CoinPack pack) async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    final success = await ref.read(giftsProvider.notifier).buyPack(pack);
    if (!mounted) return;

    if (success) {
      // Also refresh wallet provider to sync balance
      ref.read(walletProvider.notifier).refresh();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Successfully purchased ${pack.totalCoins} MSH Coins!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      final err = ref.read(giftsProvider).error ?? 'Purchase failed. Please try again.';
      setState(() {
        _isPurchasing = false;
        _errorMessage = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final giftsState = ref.watch(giftsProvider);
    final walletState = ref.watch(walletProvider);

    final packs = giftsState.packs;
    final coinBalance = giftsState.wallet?.balance ?? 0;
    final availableCash = walletState.systemBalance;

    // Default select first or popular pack if none selected
    if (_selectedPack == null && packs.isNotEmpty) {
      _selectedPack = packs.firstWhere(
        (p) => p.badge != null && p.badge!.isNotEmpty,
        orElse: () => packs.first,
      );
    }

    final sheetBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BrandColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      color: BrandColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buy MSH Coins',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Use coins to tip creators, boost posts & buy perks',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: giftsState.loading && packs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Current Coin Balance Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1A68D4), Color(0xFF1555AD)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: BrandColors.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'YOUR COIN BALANCE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        color: Color(0xFFFBBF24),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$coinBalance MSH',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'Cash: \$${availableCash.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'SELECT COIN PACKAGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Package cards
                        ...packs.map((pack) {
                          final isSelected = _selectedPack?.id == pack.id;
                          final hasBadge = pack.badge != null && pack.badge!.isNotEmpty;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPack = pack;
                                _errorMessage = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? BrandColors.primary.withValues(alpha: isDark ? 0.15 : 0.05)
                                    : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? BrandColors.primary : borderColor,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Selection radio circle
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? BrandColors.primary : borderColor,
                                        width: 2,
                                      ),
                                      color: isSelected ? BrandColors.primary : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),

                                  // Coin stack icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.monetization_on_rounded,
                                        color: Color(0xFFD97706),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Pack title & coins info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${pack.totalCoins} MSH Coins',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: textPrimary,
                                              ),
                                            ),
                                            if (hasBadge) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  pack.badge!.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFB45309),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              pack.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                            ),
                                            if (pack.bonusCoins > 0) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '+${pack.bonusCoins} Bonus',
                                                  style: const TextStyle(
                                                    color: Color(0xFF15803D),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        pack.localFormatted.isNotEmpty
                                            ? pack.localFormatted
                                            : '\$${(pack.price / 100).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: BrandColors.primary,
                                        ),
                                      ),
                                      Text(
                                        pack.currency,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Security footnote
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Secure 256-bit encrypted checkout via MurihPay Ledger',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPurchasing || _selectedPack == null
                      ? null
                      : () => _handlePurchase(_selectedPack!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: BrandColors.primary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _selectedPack != null
                              ? 'Purchase ${_selectedPack!.totalCoins} Coins for ${_selectedPack!.localFormatted.isNotEmpty ? _selectedPack!.localFormatted : '\$${(_selectedPack!.price / 100).toStringAsFixed(2)}'}'
                              : 'Select a Package',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
