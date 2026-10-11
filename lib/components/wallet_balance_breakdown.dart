import 'package:flutter/material.dart';

class WalletBalanceBreakdown extends StatelessWidget {
  final String pendingFormatted;
  final String reservedFormatted;
  final String escrowFormatted;
  final String totalFormatted;
  final bool isBalanceHidden;

  const WalletBalanceBreakdown({
    super.key,
    required this.pendingFormatted,
    required this.reservedFormatted,
    required this.escrowFormatted,
    required this.totalFormatted,
    this.isBalanceHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF6B7280);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);

    final metrics = [
      _Metric(
        label: 'Pending',
        value: pendingFormatted,
        icon: Icons.access_time_filled_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _Metric(
        label: 'Reserved',
        value: reservedFormatted,
        icon: Icons.lock_rounded,
        color: const Color(0xFF3B82F6),
      ),
      _Metric(
        label: 'Escrow',
        value: escrowFormatted,
        icon: Icons.shield_rounded,
        color: const Color(0xFF10B981),
      ),
      _Metric(
        label: 'Total Balance',
        value: totalFormatted,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics.map((m) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  m.icon,
                  size: 19,
                  color: m.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBalanceHidden ? '••••••' : m.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

