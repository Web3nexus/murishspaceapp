import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/wallet_provider.dart';
import 'brand.dart';

/// Digital receipt bottom sheet for viewing transaction details.
class TransactionDetailsSheet extends StatelessWidget {
  final WalletTransaction transaction;

  const TransactionDetailsSheet({
    super.key,
    required this.transaction,
  });

  static Future<void> show(BuildContext context, WalletTransaction transaction) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = transaction.type.toLowerCase() == 'credit';
    final isPending = transaction.status.toLowerCase() == 'pending';
    final isFailed = transaction.status.toLowerCase() == 'failed';

    final sheetBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

    final statusColor = isPending
        ? const Color(0xFFD97706)
        : (isFailed ? const Color(0xFFDC2626) : const Color(0xFF16A34A));
    final statusBg = isPending
        ? const Color(0xFFFEF3C7)
        : (isFailed ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7));

    final refId = 'TXN-${transaction.id.toString().padLeft(8, '0')}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Amount hero card
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                transaction.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Amount text
                        Text(
                          '${isCredit ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isCredit ? const Color(0xFF16A34A) : textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transaction.currency.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          transaction.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Metadata list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRow(
                          label: 'Transaction ID',
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                refId,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: refId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reference ID copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 15,
                                  color: BrandColors.primary,
                                ),
                              ),
                            ],
                          ),
                          textSecondary: textSecondary,
                        ),
                        _divider(borderColor),
                        _buildRow(
                          label: 'Date & Time',
                          value: _formatDate(transaction.createdAt),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _divider(borderColor),
                        _buildRow(
                          label: 'Type',
                          value: transaction.type.toUpperCase(),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _divider(borderColor),
                        _buildRow(
                          label: 'Ledger Method',
                          value: 'MurihPay Double-Entry',
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _divider(borderColor),
                        _buildRow(
                          label: 'Verification',
                          valueWidget: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Audited & Recorded',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Copy Reference Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: refId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction Reference copied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Reference ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BrandColors.primary,
                      side: const BorderSide(color: BrandColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Divider(height: 24, thickness: 1, color: color);
  }

  Widget _buildRow({
    required String label,
    String? value,
    Widget? valueWidget,
    Color? textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (valueWidget != null)
          valueWidget
        else
          Text(
            value ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute';
  }
}

