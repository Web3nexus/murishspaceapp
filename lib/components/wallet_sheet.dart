import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/gifts_provider.dart';
import '../providers/wallet_provider.dart';
import 'send_gift_dialog.dart';
import 'wallet_terms_dialog.dart';

/// Telegram-style slide-up Wallet modal sheet with live balance, quick actions,
/// and transaction feed, fully synchronized with walletProvider.
class WalletSheet extends ConsumerStatefulWidget {
  const WalletSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final accepted = await WalletTermsDialog.hasAccepted();
    if (!context.mounted) return;

    if (!accepted) {
      return WalletTermsDialog.show(
        context,
        onAccept: () {
          if (context.mounted) {
            _openSheet(context);
          }
        },
      );
    }

    _openSheet(context);
  }

  static void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletSheet(),
    );
  }

  @override
  ConsumerState<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<WalletSheet> {
  int _selectedAssetTab = 0; // 0: USD, 1: NGN, 2: Coins
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).refresh();
      ref.read(giftsProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14171E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF1E232E) : const Color(0xFFF1F5F9);

    final walletState = ref.watch(walletProvider);
    final coins = walletState.coinsBalance;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag indicator
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF007AFF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'MurihSpace Wallet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 16),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _hideBalance = !_hideBalance),
                  icon: Icon(
                    _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Hide balance',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(walletProvider.notifier).refresh();
                await ref.read(giftsProvider.notifier).loadAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asset Tabs: USD, NGN, Coins
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _tabPill(index: 0, label: 'USD (\$)'),
                          _tabPill(index: 1, label: 'NGN (₦)'),
                          _tabPill(index: 2, label: 'MSH Coins (🪙)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main Total Balance Card
                    _buildBalanceCard(walletState, coins, isDark),
                    const SizedBox(height: 20),

                    // Quick Action Buttons Grid (Telegram Wallet Style)
                    _buildQuickActions(context),
                    const SizedBox(height: 24),

                    // Recent Activity Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT ACTIVITY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: textSecondary,
                          ),
                        ),
                        if (walletState.transactions.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/wallet');
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Transactions List
                    if (walletState.loading && walletState.transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (walletState.transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 36, color: textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'No transactions yet',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Deposit funds, buy coins, or receive gifts to see activity here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: walletState.transactions.take(5).length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                          itemBuilder: (ctx, i) {
                            final tx = walletState.transactions[i];
                            final isCredit = tx.type == 'credit' || tx.type == 'deposit' || tx.type == 'gift_received';
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isCredit ? const Color(0xFF34C759) : const Color(0xFFFF9500)).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: isCredit ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                tx.description.isNotEmpty ? tx.description : 'Wallet Transfer',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                tx.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tx.status == 'completed' ? const Color(0xFF34C759) : Colors.orange,
                                ),
                              ),
                              trailing: Text(
                                '${isCredit ? "+" : "-"}${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isCredit ? const Color(0xFF34C759) : textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill({required int index, required String label}) {
    final isSelected = _selectedAssetTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedAssetTab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(WalletState walletState, int coins, bool isDark) {
    String balanceDisplay = '\$0.00';
    String secondaryInfo = 'Safe Escrow & Settlement Account';

    if (_hideBalance) {
      balanceDisplay = '••••••••';
    } else {
      if (_selectedAssetTab == 0) {
        balanceDisplay = '\$${walletState.systemBalance.toStringAsFixed(2)}';
        secondaryInfo = 'USD Escrow & Multi-Currency Account';
      } else if (_selectedAssetTab == 1) {
        balanceDisplay = '₦${(walletState.systemBalance * 1550).toStringAsFixed(2)}';
        secondaryInfo = 'NGN Local Currency Wallet';
      } else {
        balanceDisplay = '$coins MSH';
        secondaryInfo = 'Virtual Coins for Tipping & Gifts';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
              : [const Color(0xFF007AFF), const Color(0xFF0051C6), const Color(0xFF00388B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL AVAILABLE BALANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Escrow Protected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            balanceDisplay,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            secondaryInfo,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickActionButton(
          icon: Icons.add_circle_outline_rounded,
          label: 'Deposit',
          color: const Color(0xFF34C759),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/wallet');
          },
        ),
        _quickActionButton(
          icon: Icons.arrow_outward_rounded,
          label: 'Send',
          color: const Color(0xFF007AFF),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/wallet');
          },
        ),
        _quickActionButton(
          icon: Icons.monetization_on_rounded,
          label: 'Buy Coins',
          color: const Color(0xFFFF9500),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/gifts');
          },
        ),
        _quickActionButton(
          icon: Icons.card_giftcard_rounded,
          label: 'Gift',
          color: const Color(0xFFFF2D55),
          onTap: () {
            Navigator.of(context).pop();
            SendGiftDialog.show(
              context,
              recipientName: 'Friend',
              onGiftSent: (gift, amount) {},
            );
          },
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

