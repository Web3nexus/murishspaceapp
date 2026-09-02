import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallet_provider.dart';

class GiftOption {
  final String id;
  final String name;
  final String icon;
  final int coinCost;
  final Color color;

  const GiftOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.coinCost,
    required this.color,
  });
}

/// Universal Virtual Gifting Sheet for Profiles, Calls, Conferences & Live Streams.
class SendGiftDialog extends ConsumerStatefulWidget {
  final int? recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final Function(GiftOption gift, int amount)? onGiftSent;

  const SendGiftDialog({
    super.key,
    this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    this.onGiftSent,
  });

  static void show(
    BuildContext context, {
    int? recipientId,
    required String recipientName,
    String? recipientAvatar,
    Function(GiftOption gift, int amount)? onGiftSent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SendGiftDialog(
        recipientId: recipientId,
        recipientName: recipientName,
        recipientAvatar: recipientAvatar,
        onGiftSent: onGiftSent,
      ),
    );
  }

  @override
  ConsumerState<SendGiftDialog> createState() => _SendGiftDialogState();
}

class _SendGiftDialogState extends ConsumerState<SendGiftDialog> {
  static const _gifts = [
    GiftOption(id: 'coin', name: 'Gold Coin', icon: '🪙', coinCost: 10, color: Color(0xFFFF9500)),
    GiftOption(id: 'rose', name: 'Magic Rose', icon: '🌹', coinCost: 50, color: Color(0xFFFF3B30)),
    GiftOption(id: 'diamond', name: 'Sparkle Diamond', icon: '💎', coinCost: 200, color: Color(0xFF007AFF)),
    GiftOption(id: 'crown', name: 'Royalty Crown', icon: '👑', coinCost: 500, color: Color(0xFFFFD700)),
    GiftOption(id: 'rocket', name: 'Super Rocket', icon: '🚀', coinCost: 1000, color: Color(0xFFAF52DE)),
  ];

  GiftOption _selectedGift = _gifts[1]; // Rose default
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final userCoins = 450; // Current coin balance

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.15),
                backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
                child: widget.recipientAvatar == null
                    ? Text(
                        widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9500)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Send Gift to ${widget.recipientName}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary)),
                    Text('Support creator & boost engagement', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 13)),
                    Text('$userCoins Coins', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFF9500))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gifts Catalog Grid
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _gifts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final gift = _gifts[idx];
                final isSelected = gift.id == _selectedGift.id;

                return GestureDetector(
                  onTap: () => setState(() => _selectedGift = gift),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 86,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? gift.color.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? gift.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gift.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gift.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary), maxLines: 1),
                        Text('${gift.coinCost} coins', style: TextStyle(fontSize: 10, color: gift.color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Send Gift Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedGift.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      await Future.delayed(const Duration(milliseconds: 500));
                      widget.onGiftSent?.call(_selectedGift, _selectedGift.coinCost);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${_selectedGift.icon} ${_selectedGift.name} sent to ${widget.recipientName}!'),
                            backgroundColor: _selectedGift.color,
                          ),
                        );
                      }
                    },
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      'Send ${_selectedGift.icon} ${_selectedGift.name} (${_selectedGift.coinCost} Coins)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
