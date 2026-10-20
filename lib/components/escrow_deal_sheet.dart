import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

String _usd(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

String _holdText(String? reason) {
  if (reason == null || reason.isEmpty) return 'Funds are on hold while the order is reviewed.';
  if (reason.startsWith('manual:')) {
    return 'Our team has placed a hold on these funds while the order is reviewed.';
  }
  if (reason == 'no_delivery') {
    return 'No delivery and no contact between the buyer and seller by the check date.';
  }
  return 'Funds are on hold.';
}

/// Escrows where funds are still locked, listed in the wallet. Tapping one opens its actions.
class ActiveEscrowDeals extends ConsumerWidget {
  const ActiveEscrowDeals({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(walletProvider).escrowDeals;
    if (deals.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Active escrow deals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          for (final deal in deals)
            ListTile(
              title: Text(deal.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                deal.isOnHold ? 'On hold' : (deal.status == 'disputed' ? 'In dispute' : 'Active'),
              ),
              trailing: Text(_usd(deal.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => EscrowDealSheet.show(context, deal),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Hold status and the actions for one escrow: Continue, Confirm receipt, Release funds and Open dispute.
/// The other party's phone number is shown only for a paid order, as the server returns it.
class EscrowDealSheet extends ConsumerStatefulWidget {
  final EscrowDeal deal;

  const EscrowDealSheet({super.key, required this.deal});

  static Future<void> show(BuildContext context, EscrowDeal deal) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EscrowDealSheet(deal: deal),
    );
  }

  @override
  ConsumerState<EscrowDealSheet> createState() => _EscrowDealSheetState();
}

class _EscrowDealSheetState extends ConsumerState<EscrowDealSheet> {
  final _reason = TextEditingController();
  Map<String, dynamic>? _contact;
  bool _busy = false;
  bool _disputing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int? get _me => ref.read(authProvider).user?.id;
  bool get _isBuyer => _me != null && _me == widget.deal.buyerId;
  bool get _isSeller => _me != null && _me == widget.deal.sellerId;
  bool get _isParty => _isBuyer || _isSeller;

  Future<void> _loadContact() async {
    if (!_isParty) return;
    try {
      final res = await ApiClient.instance.dio.get('/wallet/escrow/${widget.deal.id}/counterparty-contact');
      final body = res.data;
      final payload = body is Map ? body['data'] : null;
      if (mounted && payload is Map) {
        setState(() => _contact = Map<String, dynamic>.from(payload));
      }
    } catch (_) {
      // Not shown until the order is paid, or when the request fails.
    }
  }

  Future<void> _act(String action, {Map<String, dynamic>? data, required String success}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(walletProvider.notifier).escrowAction(widget.deal.id, action, data: data);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
    messenger?.showSnackBar(SnackBar(content: Text(success)));
  }

  Future<void> _confirmRelease() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release funds now?'),
        content: const Text('These funds go to the seller straight away. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Release')),
        ],
      ),
    );
    if (ok == true) {
      await _act('release-now', success: 'Funds released to the seller.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final onHold = deal.isOnHold;
    final open = deal.status == 'held' || onHold;
    final canConfirmReceipt = _isBuyer &&
        deal.status == 'held' &&
        deal.deliveryKind == 'physical' &&
        deal.deliveredAt != null &&
        deal.buyerConfirmedAt == null;
    final textSecondary = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);
    final statusLabel = onHold
        ? 'On hold'
        : deal.status == 'disputed'
            ? 'In dispute'
            : 'Active';

    final mobile = _contact?['mobile_number'] as String?;
    final otherName = (_contact?['name'] ?? _contact?['username'])?.toString();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(deal.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: onHold ? const Color(0x26D97706) : const Color(0x1A16A34A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: onHold ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_usd(deal.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (deal.releaseAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Releases ${deal.releaseAt!.toLocal().toString().split('.').first}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
              if (onHold) ...[
                const SizedBox(height: 12),
                Text(_holdText(deal.holdReason), style: TextStyle(fontSize: 13, color: textSecondary)),
              ],
              if (_isParty && mobile != null && mobile.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Other party: ${otherName ?? ''} · $mobile',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_isParty && onHold && deal.holdReason == 'no_delivery')
                FilledButton(
                  onPressed: _busy ? null : () => _act('resume', success: 'The order is active again.'),
                  child: const Text('Continue'),
                ),
              if (canConfirmReceipt) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _act('confirm-receipt', success: 'Receipt confirmed.'),
                  child: const Text('Confirm receipt'),
                ),
              ],
              if (_isBuyer && open) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _confirmRelease,
                  child: const Text('Release funds'),
                ),
              ],
              if (_isParty && open && !_disputing) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _disputing = true),
                  child: const Text('Open dispute'),
                ),
              ],
              if (_disputing) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Describe the problem (at least 10 characters)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy || _reason.text.trim().length < 10
                      ? null
                      : () => _act(
                            'dispute',
                            data: {'reason': _reason.text.trim()},
                            success: 'Dispute opened. Our team will review it.',
                          ),
                  child: const Text('Submit dispute'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _disputing = false),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
