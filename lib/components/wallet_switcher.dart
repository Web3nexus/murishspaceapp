import 'package:flutter/material.dart';
import '../core/design_tokens.dart';
import '../providers/wallet_provider.dart';

/// Segmented wallet switcher pill matching MurihSpace brand identity.
class WalletSwitcher extends StatelessWidget {
  final WalletType activeType;
  final ValueChanged<WalletType> onChanged;
  final bool hasCreator;
  final bool hasBusiness;

  const WalletSwitcher({
    super.key,
    required this.activeType,
    required this.onChanged,
    this.hasCreator = true,
    this.hasBusiness = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E7EB);

    final items = <_SwitcherItem>[
      const _SwitcherItem(type: WalletType.system, label: 'Personal', icon: Icons.person_rounded),
      if (hasCreator)
        const _SwitcherItem(type: WalletType.creator, label: 'Creator', icon: Icons.auto_awesome_rounded),
      if (hasBusiness)
        const _SwitcherItem(type: WalletType.business, label: 'Business', icon: Icons.business_center_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = activeType == item.type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.type),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? DesignTokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: DesignTokens.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey[400] : const Color(0xFF4B5563)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SwitcherItem {
  final WalletType type;
  final String label;
  final IconData icon;

  const _SwitcherItem({
    required this.type,
    required this.label,
    required this.icon,
  });
}

