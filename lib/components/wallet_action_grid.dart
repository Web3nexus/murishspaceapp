import 'package:flutter/material.dart';
import '../core/design_tokens.dart';
import '../providers/wallet_provider.dart';

class WalletActionGrid extends StatelessWidget {
  final WalletType walletType;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSendMoney;
  final VoidCallback onBuyCoins;
  final VoidCallback onTransfer;
  final VoidCallback onLockEscrow;
  final VoidCallback? onReceive;

  const WalletActionGrid({
    super.key,
    required this.walletType,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSendMoney,
    required this.onBuyCoins,
    required this.onTransfer,
    required this.onLockEscrow,
    this.onReceive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build context-specific action items
    final actions = <_ActionItem>[
      _ActionItem(
        label: 'Deposit',
        icon: Icons.add_rounded,
        bgColor: DesignTokens.primary,
        iconColor: Colors.white,
        onTap: onDeposit,
      ),
      _ActionItem(
        label: 'Withdraw',
        icon: Icons.north_east_rounded,
        bgColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: const Color(0xFF10B981),
        onTap: onWithdraw,
      ),
    ];

    if (walletType == WalletType.system) {
      actions.add(_ActionItem(
        label: 'Send',
        icon: Icons.send_rounded,
        bgColor: DesignTokens.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: DesignTokens.primary,
        onTap: onSendMoney,
      ));
      if (onReceive != null) {
        actions.add(_ActionItem(
          label: 'Receive',
          icon: Icons.qr_code_rounded,
          bgColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
          iconColor: const Color(0xFF6366F1),
          onTap: onReceive!,
        ));
      }
      actions.add(_ActionItem(
        label: 'Buy Coins',
        icon: Icons.monetization_on_rounded,
        bgColor: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: const Color(0xFFF59E0B),
        onTap: onBuyCoins,
      ));
    } else if (walletType == WalletType.creator) {
      actions.add(_ActionItem(
        label: 'Transfer',
        icon: Icons.swap_horiz_rounded,
        bgColor: DesignTokens.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: DesignTokens.primary,
        onTap: onTransfer,
      ));
      actions.add(_ActionItem(
        label: 'Buy Coins',
        icon: Icons.monetization_on_rounded,
        bgColor: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: const Color(0xFFF59E0B),
        onTap: onBuyCoins,
      ));
    } else {
      // Business
      actions.add(_ActionItem(
        label: 'Transfer',
        icon: Icons.swap_horiz_rounded,
        bgColor: DesignTokens.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: DesignTokens.primary,
        onTap: onTransfer,
      ));
      actions.add(_ActionItem(
        label: 'Lock Escrow',
        icon: Icons.shield_rounded,
        bgColor: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
        iconColor: const Color(0xFFF59E0B),
        onTap: onLockEscrow,
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((act) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: act.onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: act.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: act.bgColor == DesignTokens.primary
                          ? [
                              BoxShadow(
                                color: DesignTokens.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        act.icon,
                        color: act.iconColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                act.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });
}

