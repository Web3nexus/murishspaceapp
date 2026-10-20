import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallet_provider.dart';

String _usd(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// Refunds from disputes the buyer won. The money can be spent on purchases or gifts, but not withdrawn.
/// "Send to card" refunds it to the card that paid for the order.
class RefundBalancesCard extends ConsumerStatefulWidget {
  const RefundBalancesCard({super.key});

  @override
  ConsumerState<RefundBalancesCard> createState() => _RefundBalancesCardState();
}

class _RefundBalancesCardState extends ConsumerState<RefundBalancesCard> {
  int? _busyId;
  String? _message;
  bool _ok = false;

  Future<void> _sendToCard(RefundBalance refund) async {
    setState(() {
      _busyId = refund.id;
      _message = null;
    });
    final error = await ref.read(walletProvider.notifier).refundToCard(refund.id);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _ok = error == null;
      _message = error ?? 'Refund sent to the card that paid for this order.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final refunds = ref.watch(walletProvider).refundBalances;
    if (refunds.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dispute refunds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Refunds from disputes you won. Spend them on purchases or gifts, or send them back to the card that paid. '
            'They cannot be withdrawn.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ok ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          for (final refund in refunds) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_usd(refund.amountUsd)} · order #${refund.orderId}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Charged ${refund.originalAmount} ${refund.originalCurrency}'
                        '${refund.status == 'refunded_to_card' ? ' · sent to card' : ''}'
                        '${refund.failureReason != null ? ' · ${refund.failureReason}' : ''}',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                if (refund.canSendToCard)
                  FilledButton(
                    onPressed: _busyId == refund.id ? null : () => _sendToCard(refund),
                    child: Text(_busyId == refund.id ? 'Sending…' : 'Send to card'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
