import 'package:flutter/material.dart';
import '../core/design_tokens.dart';
import '../providers/wallet_provider.dart';

class WalletTransactionsList extends StatefulWidget {
  final List<WalletTransaction> transactions;
  final ValueChanged<WalletTransaction> onSelect;
  final bool isBalanceHidden;

  const WalletTransactionsList({
    super.key,
    required this.transactions,
    required this.onSelect,
    this.isBalanceHidden = false,
  });

  @override
  State<WalletTransactionsList> createState() => _WalletTransactionsListState();
}

class _WalletTransactionsListState extends State<WalletTransactionsList> {
  String _activeFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final _filters = ['All', 'Income', 'Expenses', 'Escrow'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);

    // Filter logic
    final filtered = widget.transactions.where((tx) {
      if (_activeFilter == 'Income' && tx.type != 'credit') return false;
      if (_activeFilter == 'Expenses' && tx.type != 'debit') return false;
      if (_activeFilter == 'Escrow' && !tx.description.toLowerCase().contains('escrow')) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return tx.description.toLowerCase().contains(q) ||
            tx.amount.toString().contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSel = _activeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : textSecondary,
                    ),
                  ),
                  selected: isSel,
                  selectedColor: DesignTokens.primary,
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                  side: BorderSide(
                    color: isSel ? DesignTokens.primary : borderColor,
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) setState(() => _activeFilter = f);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Standard Fintech Search Field (No nested box-in-box)
        TextField(
          controller: _searchCtrl,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search transactions...',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF3F5F8),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: textSecondary,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: textSecondary),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 16),

        // Transactions List or Empty State
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 36, color: textSecondary),
                const SizedBox(height: 10),
                Text(
                  'No transactions found',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _searchQuery.isNotEmpty
                    ? 'No records match your search criteria.'
                    : 'Activity and ledger records will appear here as transactions settle.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.6,
                color: borderColor,
                indent: 64,
              ),
              itemBuilder: (ctx, i) {
                final tx = filtered[i];
                final isCredit = tx.type == 'credit';
                final meta = _resolveMeta(tx.description);

                final timeStr = '${tx.createdAt.hour > 12 ? tx.createdAt.hour - 12 : tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')} ${tx.createdAt.hour >= 12 ? 'PM' : 'AM'}';

                return InkWell(
                  onTap: () => widget.onSelect(tx),
                  borderRadius: i == 0
                      ? const BorderRadius.vertical(top: Radius.circular(18))
                      : i == filtered.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(18))
                          : BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        // Icon circle
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: meta.bgColor.withValues(alpha: isDark ? 0.22 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            meta.icon,
                            color: meta.iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.description,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    meta.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(' · ', style: TextStyle(color: textSecondary, fontSize: 11)),
                                  Text(
                                    timeStr,
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

                        // Status pill & Signed Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.isBalanceHidden
                                  ? '••••'
                                  : '${isCredit ? "+" : "-"} \$${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  _TxMeta _resolveMeta(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('coin') || d.contains('msh')) {
      return const _TxMeta(
        icon: Icons.monetization_on_rounded,
        bgColor: Color(0xFFF59E0B),
        iconColor: Color(0xFFF59E0B),
        category: 'MSH Coins Purchase',
      );
    }
    if (d.contains('escrow')) {
      return const _TxMeta(
        icon: Icons.shield_rounded,
        bgColor: Color(0xFF10B981),
        iconColor: Color(0xFF10B981),
        category: 'Escrow Security',
      );
    }
    if (d.contains('bank') || d.contains('withdraw')) {
      return const _TxMeta(
        icon: Icons.account_balance_rounded,
        bgColor: DesignTokens.primary,
        iconColor: DesignTokens.primary,
        category: 'Bank Payout',
      );
    }
    if (d.contains('gift') || d.contains('tip')) {
      return const _TxMeta(
        icon: Icons.card_giftcard_rounded,
        bgColor: Color(0xFFEC4899),
        iconColor: Color(0xFFEC4899),
        category: 'Gift & Tip',
      );
    }
    if (d.contains('sent') || d.contains('transfer')) {
      return const _TxMeta(
        icon: Icons.send_rounded,
        bgColor: Color(0xFF3B82F6),
        iconColor: Color(0xFF3B82F6),
        category: 'Transfer Out',
      );
    }
    return const _TxMeta(
      icon: Icons.arrow_downward_rounded,
      bgColor: Color(0xFF10B981),
      iconColor: Color(0xFF10B981),
      category: 'Inflow Payment',
    );
  }
}

class _TxMeta {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String category;

  const _TxMeta({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.category,
  });
}
