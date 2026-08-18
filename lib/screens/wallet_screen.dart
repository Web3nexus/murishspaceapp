import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/currency_formatter.dart';
import '../providers/gifts_provider.dart';
import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';

/// Ultra-Fancy Revolut & Apple Pay Hybrid Escrow & Multi-Currency Financial Hub.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  bool _hideBalance = false;
  int _activeCardIndex = 0;
  CoinPack? _buying;

  // Active Escrow Contracts Mock Data
  final List<Map<String, dynamic>> _escrowContracts = [
    {
      'id': 'ESC-8921',
      'title': 'Solstar Inverter & Solar Battery',
      'party': 'Lagos Solar Tech (@solartech_ng)',
      'amount': '₦120,000.00',
      'status': 'In Transit (Fulfillment)',
      'statusColor': const Color(0xFFFF9500),
      'progress': 0.7,
      'buyerRole': true,
      'details': 'Product shipped via GIG Logistics. Track ID: GIG-981240.',
    },
    {
      'id': 'ESC-8922',
      'title': 'Nike Air Campaign Video Sponsorship',
      'party': 'Nike Africa Brand Team (@nike_ng)',
      'amount': '\$450.00',
      'status': 'Draft Review',
      'statusColor': const Color(0xFF007AFF),
      'progress': 0.4,
      'buyerRole': false,
      'details': 'Draft video submitted by creator. Pending brand approval.',
    },
    {
      'id': 'ESC-8923',
      'title': 'Custom Mobile App UI Design',
      'party': 'Alex Johnson (@alex_j)',
      'amount': '\$850.00',
      'status': 'Funds Locked',
      'statusColor': const Color(0xFF34C759),
      'progress': 0.9,
      'buyerRole': true,
      'details': 'Final deliverables verified. Awaiting release confirmation.',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).refresh();
      ref.read(giftsProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _buy(CoinPack pack) async {
    setState(() => _buying = pack);
    final ok = await ref.read(giftsProvider.notifier).buyPack(pack);
    if (!mounted) return;
    setState(() => _buying = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Added ${pack.totalCoins} MSH coins to your wallet!'
            : ref.read(giftsProvider).error ?? 'Purchase failed.'),
        backgroundColor: const Color(0xFF34C759),
      ),
    );
  }

  void _openCreateEscrowModal() {
    final titleController = TextEditingController();
    final partyController = TextEditingController();
    final amountController = TextEditingController();

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
                      color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF007AFF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Escrow Agreement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Agreement Title / Item Name',
                  hintText: 'e.g., iPhone 15 Pro Max Purchase',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: partyController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Counterparty Handle or Phone',
                  hintText: 'e.g., @seller_handle or +234...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  labelText: 'Escrow Amount (NGN)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final party = partyController.text.trim();
                    final amount = amountController.text.trim();
                    if (title.isNotEmpty && amount.isNotEmpty) {
                      setState(() {
                        _escrowContracts.insert(0, {
                          'id': 'ESC-${8924 + _escrowContracts.length}',
                          'title': title,
                          'party': party.isEmpty ? 'Counterparty' : party,
                          'amount': '₦$amount.00',
                          'status': 'Funds Locked (Escrow)',
                          'statusColor': const Color(0xFF34C759),
                          'progress': 0.5,
                          'buyerRole': true,
                          'details': 'Escrow deal initiated. Funds locked securely.',
                        });
                      });
                      Navigator.pop(ctx);
                      _tab.animateTo(1); // Switch to Escrow tab
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Escrow agreement "$title" created! ₦$amount locked in escrow.'),
                          backgroundColor: const Color(0xFF34C759),
                        ),
                      );
                    }
                  },
                  child: const Text('Lock Funds in Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReleaseEscrowDialog(Map<String, dynamic> contract) {
    final pinController = TextEditingController();
    final security = ref.read(securityProvider);

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
              Text('Release Escrow Funds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 6),
              Text('Confirm that you have received "${contract['title']}" in good condition. Funds will be released to ${contract['party']}.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 16),
              if (security.isTransactionPinSet) ...[
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_rounded),
                    labelText: 'Enter 4-Digit Transaction PIN',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (security.isTransactionPinSet) {
                      final okPin = await ref.read(securityProvider.notifier).verifyTransactionPin(pinController.text.trim());
                      if (!okPin) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid Transaction PIN.')),
                        );
                        return;
                      }
                    }
                    setState(() {
                      contract['status'] = 'Completed & Released';
                      contract['statusColor'] = const Color(0xFF34C759);
                      contract['progress'] = 1.0;
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Released ${contract['amount']} to ${contract['party']}!'),
                          backgroundColor: const Color(0xFF34C759),
                        ),
                      );
                    }
                  },
                  child: const Text('Confirm & Release Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDepositModal() {
    final amountController = TextEditingController(text: '5000');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deposit Funds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  labelText: 'Deposit Amount (NGN)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    final raw = int.tryParse(amountController.text.trim()) ?? 5000;
                    await ref.read(walletProvider.notifier).deposit(amount: raw * 100);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deposit of ₦$raw successful!'), backgroundColor: const Color(0xFF34C759)));
                    }
                  },
                  child: const Text('Proceed to Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openWithdrawModal() {
    final amountController = TextEditingController(text: '10000');
    final pinController = TextEditingController();
    final security = ref.read(securityProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Withdraw to Bank Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  labelText: 'Withdrawal Amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              if (security.isTransactionPinSet) ...[
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_rounded),
                    labelText: 'Enter 4-Digit Transaction PIN',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    final raw = int.tryParse(amountController.text.trim()) ?? 10000;
                    if (security.isTransactionPinSet) {
                      final okPin = await ref.read(securityProvider.notifier).verifyTransactionPin(pinController.text.trim());
                      if (!okPin) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Transaction PIN.')));
                        return;
                      }
                    }
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal of ₦$raw submitted to your Bank!'), backgroundColor: const Color(0xFF34C759)));
                    }
                  },
                  child: const Text('Confirm Withdrawal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final gifts = ref.watch(giftsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Financial & Escrow Hub',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF007AFF)),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
            tooltip: 'Hide balance',
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Color(0xFF34C759)),
            onPressed: () => context.push('/profile/security'),
            tooltip: 'Security Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: textSecondary,
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Escrow Deals'),
            Tab(text: 'Wallets'),
            Tab(text: 'Buy Coins'),
            Tab(text: 'Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Tab 1: Overview ──────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(walletProvider.notifier).refresh();
              await ref.read(giftsProvider.notifier).loadAll();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFancyVirtualCard(walletState, isDark),
                const SizedBox(height: 18),
                _buildQuickActionGrid(isDark),
                const SizedBox(height: 20),
                _buildEscrowProtectionBanner(isDark),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Escrow Agreements', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary)),
                    TextButton(
                      onPressed: () => _tab.animateTo(1),
                      child: const Text('View All >', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._escrowContracts.take(2).map((c) => _buildEscrowContractCard(c, isDark)),
              ],
            ),
          ),

          // ── Tab 2: Escrow Deals Hub ──────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Escrow Contracts Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _openCreateEscrowModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Deal', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Funds are locked safely in escrow until order delivery or contract milestone is confirmed.', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 16),
              ..._escrowContracts.map((c) => _buildEscrowContractCard(c, isDark)),
            ],
          ),

          // ── Tab 3: Wallets Details ───────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Multi-Currency Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 6),
              Text('Separate balances for system purchases, creator tips, and business store sales.', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 16),
              _walletCards(walletState, isDark),
            ],
          ),

          // ── Tab 4: Buy Coins ──────────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Buy MSH Coin Packs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 6),
              Text('Send virtual gifts to live creators, tip videos, and unlock premium features.', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 16),
              if (gifts.loading && gifts.packs.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: LoadingStateWidget(message: 'Loading coin packs…'))
              else
                ...gifts.packs.map((pack) => _packCard(pack, isDark)),
            ],
          ),

          // ── Tab 5: Ledger ─────────────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Financial Ledger & Receipts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 16),
              _buildLedgerTile('Solstar Solar Escrow Purchase', 'Locked in Escrow · Today 02:15 PM', '- ₦120,000.00', const Color(0xFFFF9500), isDark),
              _buildLedgerTile('Wallet Bank Deposit', 'Completed via Card · Today 11:30 AM', '+ ₦50,000.00', const Color(0xFF34C759), isDark),
              _buildLedgerTile('Sent Diamond Gift to @samuel', 'Creator Tip · Yesterday', '- 1,000 MSH', const Color(0xFF5856D6), isDark),
              _buildLedgerTile('Brand Sponsorship Payout Released', 'Escrow Released · 2 days ago', '+ ₦185,000.00', const Color(0xFF34C759), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFancyVirtualCard(WalletState state, bool isDark) {
    final system = state.wallets.where((w) => w.type == WalletType.system).firstOrNull;
    final cashMinorUnits = system?.available ?? 1450000;
    final coinBalance = cashMinorUnits ~/ 100;
    final currency = system?.currency ?? 'NGN';

    final cardGradients = [
      const [Color(0xFF007AFF), Color(0xFF5856D6)],
      const [Color(0xFF5856D6), Color(0xFFFF2D55)],
      const [Color(0xFFFF9500), Color(0xFFFF3B30)],
    ];

    final cardTitles = ['SYSTEM WALLET', 'CREATOR EARNINGS', 'BUSINESS ESCROW STORE'];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradients[_activeCardIndex % cardGradients.length],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardGradients[_activeCardIndex % cardGradients.length][0].withValues(alpha: 0.4),
            blurRadius: 18,
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
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF34C759), size: 18),
                  const SizedBox(width: 6),
                  Text(cardTitles[_activeCardIndex % cardTitles.length], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _activeCardIndex = (_activeCardIndex + 1) % 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('Switch Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.swap_horizontal_circle_outlined, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Total Available Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _hideBalance ? '••••••••' : CurrencyFormatter.format(cashMinorUnits, currency),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('•••• •••• •••• 9842', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
              Text(_hideBalance ? 'MSH: ••••' : '${coinBalance.toString()} MSH', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(bool isDark) {
    return Row(
      children: [
        Expanded(child: _quickActionButton(icon: Icons.add_rounded, label: 'Deposit', color: const Color(0xFF007AFF), onTap: _openDepositModal, isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _quickActionButton(icon: Icons.south_west_rounded, label: 'Withdraw', color: const Color(0xFF34C759), onTap: _openWithdrawModal, isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _quickActionButton(icon: Icons.shield_rounded, label: 'Lock Escrow', color: const Color(0xFFFF9500), onTap: _openCreateEscrowModal, isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _quickActionButton(icon: Icons.monetization_on_rounded, label: 'Buy Coins', color: const Color(0xFF5856D6), onTap: () => _tab.animateTo(3), isDark: isDark)),
      ],
    );
  }

  Widget _quickActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildEscrowProtectionBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF007AFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MurihSpace Buyer & Seller Escrow', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                Text('Funds locked in escrow are automatically released upon delivery confirmation.', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowContractCard(Map<String, dynamic> c, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final color = c['statusColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                    Text('Party: ${c['party']} · ID: ${c['id']}', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Text(c['amount'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF007AFF))),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: c['progress'] as double,
            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c['status'] as String, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                onPressed: () => _showReleaseEscrowDialog(c),
                child: const Text('Release Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletCards(WalletState state, bool isDark) {
    if (state.loading && state.wallets.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LoadingStateWidget(message: 'Loading wallets…'));
    }
    return Column(
      children: state.wallets.map((wallet) => _walletCard(wallet, isDark)).toList(),
    );
  }

  Widget _walletCard(Wallet wallet, bool isDark) {
    final isSystem = wallet.type == WalletType.system;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF007AFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(isSystem ? Icons.savings_rounded : Icons.business_center_rounded, color: const Color(0xFF007AFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_typeLabel(wallet.type), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                    Text('${wallet.currency} · ${wallet.status}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Text(CurrencyFormatter.format(wallet.available, wallet.currency), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF007AFF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _packCard(CoinPack pack, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pack.coins} MSH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                Text(pack.badge ?? CurrencyFormatter.format(pack.price, pack.currency), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _buying?.id == pack.id ? null : () => _buy(pack),
            child: _buying?.id == pack.id
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(CurrencyFormatter.format(pack.price, pack.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTile(String title, String subtitle, String amount, Color color, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Text(amount, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
        ],
      ),
    );
  }

  String _typeLabel(WalletType type) {
    switch (type) {
      case WalletType.system:
        return 'System Wallet';
      case WalletType.creator:
        return 'Creator Wallet';
      case WalletType.business:
        return 'Business Store Wallet';
    }
  }
}
