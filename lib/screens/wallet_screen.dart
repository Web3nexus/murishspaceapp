import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gifts_provider.dart';
import '../components/ui_states.dart';

/// Wallet screen: shows coin balance and lets users buy coin packs.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  CoinPack? _buying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftsProvider.notifier).loadAll();
    });
  }

  String _formatPrice(CoinPack pack) {
    final syms = {'NGN': '₦', 'USD': r'$', 'GBP': '£', 'EUR': '€'};
    final sym = syms[pack.currency] ?? '${pack.currency} ';
    return '$sym${(pack.price / 100).toStringAsFixed(2)}';
  }

  Future<void> _buy(CoinPack pack) async {
    setState(() => _buying = pack);
    final ok = await ref.read(giftsProvider.notifier).buyPack(pack);
    if (!mounted) return;
    setState(() => _buying = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Added ${pack.totalCoins} coins to your wallet!'
            : ref.read(giftsProvider).error ?? 'Purchase failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(giftsProvider);
    final wallet = state.wallet;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(giftsProvider.notifier).loadAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coin Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wallet != null
                        ? '${wallet.balance.toString()} MSH'
                        : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buy Coins',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Send gifts to creators',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.loading && wallet == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: LoadingStateWidget(message: 'Loading packs…'),
              )
            else if (state.packs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: EmptyStateWidget(
                  icon: Icons.monetization_on_outlined,
                  title: 'No coin packs',
                  description: 'Coin packs will appear here once available.',
                ),
              )
            else
              ...state.packs.map(
                (pack) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.monetization_on,
                            color: Colors.amber.shade800),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pack.coins.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MSH',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                if (pack.bonusCoins > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${pack.bonusCoins} bonus',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pack.badge ?? _formatPrice(pack),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _buying?.id == pack.id
                            ? null
                            : () => _buy(pack),
                        child: _buying?.id == pack.id
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_formatPrice(pack)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Recent Purchases',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...state.transactions.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No purchases yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ]
                : state.transactions.take(5).map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.card_giftcard),
                      title: Text('Sent ${t.giftName}'),
                      subtitle: Text(
                        t.senderName ?? 'Anonymous',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${t.coinPrice} MSH',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
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
