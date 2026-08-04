import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/currency_formatter.dart';
import '../core/design_tokens.dart';
import '../providers/gifts_provider.dart';
import '../providers/wallet_provider.dart';

/// Wallet screen (Sprint M6): multi-wallet balances (system/creator/business),
/// deposit, internal transfer, fee preview, and coin packs.
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
      ref.read(walletProvider.notifier).refresh();
      ref.read(giftsProvider.notifier).loadAll();
    });
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

  void _openDeposit() {
    showDialog<void>(
      context: context,
      builder: (_) => _DepositDialog(
        onSubmitted: (amount) async {
          final ok = await ref.read(walletProvider.notifier).deposit(amount: amount);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? 'Deposit successful.'
                    : ref.read(walletProvider).error ?? 'Deposit failed.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openTransfer(WalletType fromType) {
    final wallet = ref.read(walletProvider.notifier).walletOf(fromType);
    if (wallet == null || wallet.withdrawable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No withdrawable balance in this wallet yet.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _TransferDialog(
        fromType: fromType,
        maxAmount: wallet.withdrawable,
        currency: wallet.currency,
        onSubmitted: (amount) async {
          final ok = await ref
              .read(walletProvider.notifier)
              .internalTransfer(fromType: fromType.apiValue, amount: amount);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? 'Transferred to your system wallet.'
                    : ref.read(walletProvider).error ?? 'Transfer failed.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFeePreview() {
    showDialog<void>(
      context: context,
      builder: (_) => _FeePreviewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final gifts = ref.watch(giftsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletProvider.notifier).refresh();
          await ref.read(giftsProvider.notifier).loadAll();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _walletHero(walletState),
            const SizedBox(height: 16),
            _walletCards(walletState),
            if (walletState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                walletState.error!,
                style: const TextStyle(color: DesignTokens.danger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_card,
                    label: 'Deposit',
                    onPressed: _openDeposit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.swap_horiz,
                    label: 'Fee Preview',
                    onPressed: _openFeePreview,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buy Coins',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Send gifts to creators',
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (gifts.loading && gifts.packs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: LoadingStateWidget(message: 'Loading packs…'),
              )
            else if (gifts.packs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: EmptyStateWidget(
                  icon: Icons.monetization_on_outlined,
                  title: 'No coin packs',
                  description: 'Coin packs will appear here once available.',
                ),
              )
            else
              ...gifts.packs.map((pack) => _packTile(pack, theme)),
            const SizedBox(height: 24),
            Text(
              'Recent Purchases',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...gifts.transactions.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No purchases yet.',
                          style: TextStyle(color: DesignTokens.textSecondary),
                        ),
                      ),
                    ),
                  ]
                : gifts.transactions.take(5).map(
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

  Widget _walletHero(WalletState state) {
    final system = state.wallets.where((w) => w.type == WalletType.system).firstOrNull;
    final cashMinorUnits = system?.available ?? 0;
    final coinBalance = cashMinorUnits ~/ 100;
    final currency = system?.currency ?? 'NGN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignTokens.primaryDark, DesignTokens.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
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
            state.loading && state.wallets.isEmpty
                ? '…'
                : '${coinBalance.toString()} MSH',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cash balance: ${CurrencyFormatter.format(cashMinorUnits, currency)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _walletCards(WalletState state) {
    if (state.loading && state.wallets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingStateWidget(message: 'Loading wallets…'),
      );
    }
    if (state.wallets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No wallets yet',
        description: 'Your wallets will appear here once available.',
      );
    }
    return Column(
      children: state.wallets.map((wallet) => _walletCard(wallet)).toList(),
    );
  }

  Widget _walletCard(Wallet wallet) {
    final isSystem = wallet.type == WalletType.system;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSystem ? Icons.savings_outlined : Icons.business_outlined,
                    color: DesignTokens.primaryDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(wallet.type),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${wallet.currency} · ${wallet.status}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(wallet.available, wallet.currency),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BalanceChip('Pending', wallet.pending, wallet.currency),
                _BalanceChip('Reserved', wallet.reserved, wallet.currency),
                _BalanceChip('Escrow', wallet.escrow, wallet.currency),
                _BalanceChip('Withdrawable', wallet.withdrawable, wallet.currency),
                _BalanceChip('Disputed', wallet.disputed, wallet.currency),
              ],
            ),
            if (!isSystem && wallet.withdrawable > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openTransfer(wallet.type),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Transfer to wallet'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _packTile(CoinPack pack, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monetization_on, color: Colors.amber.shade800),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text('MSH', style: TextStyle(color: Colors.grey.shade600)),
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
                  pack.badge ?? CurrencyFormatter.format(pack.price, pack.currency),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _buying?.id == pack.id ? null : () => _buy(pack),
            child: _buying?.id == pack.id
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(CurrencyFormatter.format(pack.price, pack.currency)),
          ),
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
        return 'Business Wallet';
    }
  }
}

class _BalanceChip extends StatelessWidget {
  final String label;
  final int amount;
  final String currency;

  const _BalanceChip(this.label, this.amount, this.currency);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${CurrencyFormatter.format(amount, currency)}',
        style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: DesignTokens.primary),
        foregroundColor: DesignTokens.primaryDark,
      ),
    );
  }
}

class _DepositDialog extends ConsumerStatefulWidget {
  final Future<void> Function(int) onSubmitted;

  const _DepositDialog({required this.onSubmitted});

  @override
  ConsumerState<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends ConsumerState<_DepositDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deposit Funds'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add cash to your system wallet. Amounts are in the minor unit (e.g. 1000 = ₦10.00).',
            style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (minor units)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  final amount = int.tryParse(_controller.text.trim());
                  if (amount == null || amount < 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an amount of at least 100.')),
                    );
                    return;
                  }
                  setState(() => _submitting = true);
                  await widget.onSubmitted(amount);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Deposit'),
        ),
      ],
    );
  }
}

class _TransferDialog extends ConsumerStatefulWidget {
  final WalletType fromType;
  final int maxAmount;
  final String currency;
  final Future<void> Function(int) onSubmitted;

  const _TransferDialog({
    required this.fromType,
    required this.maxAmount,
    required this.currency,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.fromType == WalletType.creator
        ? 'Creator Wallet'
        : 'Business Wallet';

    return AlertDialog(
      title: const Text('Transfer to Wallet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move earnings from your $label to your system wallet. '
            'Available: ${CurrencyFormatter.format(widget.maxAmount, widget.currency)}',
            style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (minor units)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  final amount = int.tryParse(_controller.text.trim());
                  if (amount == null || amount < 100 || amount > widget.maxAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid amount within your balance.'),
                      ),
                    );
                    return;
                  }
                  setState(() => _submitting = true);
                  await widget.onSubmitted(amount);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Transfer'),
        ),
      ],
    );
  }
}

class _FeePreviewDialog extends ConsumerStatefulWidget {
  const _FeePreviewDialog();

  @override
  ConsumerState<_FeePreviewDialog> createState() => _FeePreviewDialogState();
}

class _FeePreviewDialogState extends ConsumerState<_FeePreviewDialog> {
  final _amountController = TextEditingController();
  String _code = 'INTERNAL_TRANSFER';
  FeePreview? _result;
  bool _loading = false;

  static const _codes = [
    'INTERNAL_TRANSFER',
    'DEPOSIT_PAYSTACK',
    'P2P_TRANSFER',
    'WITHDRAWAL',
    'GIFT',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(walletProvider.notifier)
        .previewFees(amount: amount, code: _code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(walletProvider).error ?? 'Could not load fee preview.',
          ),
        ),
      );
    }
  }

  String _money(int v) => CurrencyFormatter.format(v, _result?.currency ?? 'NGN');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fee Preview'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _code,
              decoration: const InputDecoration(
                labelText: 'Transaction code',
                border: OutlineInputBorder(),
              ),
              items: _codes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() {
                _code = v ?? _code;
                _result = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (minor units)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : () => _preview(),                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Preview fees'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              _PreviewRow('Gross amount', _money(_result!.grossAmount)),
              _PreviewRow('Platform fee', _money(_result!.platformFee)),
              _PreviewRow('Processing fee', _money(_result!.processingFee)),
              _PreviewRow('You receive', _money(_result!.recipientAmount)),
              const Divider(height: 20),
              _PreviewRow('Total charged', _money(_result!.totalCharged), bold: true),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PreviewRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? DesignTokens.textPrimary : DesignTokens.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
