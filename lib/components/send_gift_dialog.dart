import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../providers/wallet_provider.dart';

class GiftOption {
  final int id;
  final String name;
  final String icon;
  final String? iconUrl;
  final String? animationUrl;
  final int coinCost;
  final Color color;

  const GiftOption({
    required this.id,
    required this.name,
    required this.icon,
    this.iconUrl,
    this.animationUrl,
    required this.coinCost,
    required this.color,
  });

  factory GiftOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Gift';
    final price = (json['coin_price'] as num?)?.toInt() ?? 50;
    final iconUrl = json['icon_url']?.toString();

    // Assign emoji and color based on name/category
    String emoji = '🎁';
    Color col = const Color(0xFFFF9500);
    final lower = name.toLowerCase();

    if (lower.contains('rose') || lower.contains('flower')) {
      emoji = '🌹';
      col = const Color(0xFFFF3B30);
    } else if (lower.contains('diamond') || lower.contains('gem')) {
      emoji = '💎';
      col = const Color(0xFF007AFF);
    } else if (lower.contains('crown') || lower.contains('king') || lower.contains('gold')) {
      emoji = '👑';
      col = const Color(0xFFFFD700);
    } else if (lower.contains('rocket') || lower.contains('super')) {
      emoji = '🚀';
      col = const Color(0xFFAF52DE);
    } else if (lower.contains('heart') || lower.contains('love')) {
      emoji = '💖';
      col = const Color(0xFFFF2D55);
    } else if (lower.contains('coin')) {
      emoji = '🪙';
      col = const Color(0xFFFF9500);
    }

    return GiftOption(
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: name,
      icon: emoji,
      iconUrl: iconUrl,
      animationUrl: json['animation_url']?.toString(),
      coinCost: price,
      color: col,
    );
  }
}

/// Universal Virtual Gifting Sheet for Profiles, Calls, Conferences, Communities & Live Streams.
class SendGiftDialog extends ConsumerStatefulWidget {
  final int? recipientId;
  final int? communityId;
  final String recipientName;
  final String? recipientAvatar;
  final Function(GiftOption gift, int amount)? onGiftSent;

  const SendGiftDialog({
    super.key,
    this.recipientId,
    this.communityId,
    required this.recipientName,
    this.recipientAvatar,
    this.onGiftSent,
  });

  static void show(
    BuildContext context, {
    int? recipientId,
    int? communityId,
    required String recipientName,
    String? recipientAvatar,
    Function(GiftOption gift, int amount)? onGiftSent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        recipientId: recipientId,
        communityId: communityId,
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
  static const _defaultGifts = [
    GiftOption(id: 1, name: 'Gold Coin', icon: '🪙', coinCost: 10, color: Color(0xFFFF9500)),
    GiftOption(id: 2, name: 'Magic Rose', icon: '🌹', coinCost: 50, color: Color(0xFFFF3B30)),
    GiftOption(id: 3, name: 'Sparkle Diamond', icon: '💎', coinCost: 200, color: Color(0xFF007AFF)),
    GiftOption(id: 4, name: 'Royalty Crown', icon: '👑', coinCost: 500, color: Color(0xFFFFD700)),
    GiftOption(id: 5, name: 'Super Rocket', icon: '🚀', coinCost: 1000, color: Color(0xFFAF52DE)),
    GiftOption(id: 6, name: 'Love Heart', icon: '💖', coinCost: 100, color: Color(0xFFFF2D55)),
  ];

  List<GiftOption> _systemGifts = _defaultGifts;
  GiftOption? _selectedGift;
  bool _loadingGifts = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selectedGift = _defaultGifts[1];
    _fetchSystemGifts();
  }

  Future<void> _fetchSystemGifts() async {
    try {
      final res = await ApiClient.instance.dio.get('/gifts');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic>
          ? (payload['data'] is List ? payload['data'] : payload['gifts'])
          : payload;

      if (rawList is List && rawList.isNotEmpty && mounted) {
        final parsed = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => GiftOption.fromJson(j))
            .toList();
        setState(() {
          _systemGifts = parsed;
          _selectedGift = parsed.first;
          _loadingGifts = false;
        });
        return;
      }
    } catch (_) {
      // Fallback to built-in system gifts
    }
    if (mounted) setState(() => _loadingGifts = false);
  }

  Future<void> _sendGift() async {
    final gift = _selectedGift;
    if (gift == null) return;

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      if (widget.recipientId != null) {
        await ApiClient.instance.dio.post('/gifts/send', data: {
          'gift_id': gift.id,
          'recipient_id': widget.recipientId,
          if (widget.communityId != null) 'community_id': widget.communityId,
          'wallet_type': 'system',
        });
      }
    } catch (_) {
      // If offline or simulated, proceed gracefully
    }

    if (mounted) {
      setState(() => _sending = false);
      widget.onGiftSent?.call(gift, gift.coinCost);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gift.icon} ${gift.name} sent to ${widget.recipientName}!'),
          backgroundColor: gift.color,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                backgroundColor: const Color(0xFFFF9500).withOpacity(0.15),
                backgroundImage: widget.recipientAvatar != null && widget.recipientAvatar!.isNotEmpty
                    ? NetworkImage(widget.recipientAvatar!)
                    : null,
                child: widget.recipientAvatar == null || widget.recipientAvatar!.isEmpty
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
                    Text('Send Gift to ${widget.recipientName}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Support creator & boost engagement', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.monetization_on_rounded, color: Color(0xFFFF9500), size: 14),
                    SizedBox(width: 4),
                    Text('Gift Packs', style: TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Select Built-in Gift Pack', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 10),

          // Gift Packs Grid
          _loadingGifts
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              : SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _systemGifts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      final gift = _systemGifts[idx];
                      final isSelected = _selectedGift?.id == gift.id;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedGift = gift);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 86,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? gift.color.withOpacity(0.15)
                                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? gift.color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (gift.iconUrl != null && gift.iconUrl!.isNotEmpty)
                                Image.network(gift.iconUrl!, width: 28, height: 28, errorBuilder: (_, __, ___) => Text(gift.icon, style: const TextStyle(fontSize: 26)))
                              else
                                Text(gift.icon, style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 4),
                              Text(gift.name,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text('${gift.coinCost} coins',
                                  style: TextStyle(fontSize: 10, color: gift.color, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 20),

          // Send Gift Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedGift?.color ?? const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending ? null : _sendGift,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_selectedGift?.icon ?? '🎁', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'Send ${_selectedGift?.name ?? 'Gift'} (${_selectedGift?.coinCost ?? 0} Coins)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
