import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import 'gift_animation_overlay.dart';
import 'wallet_sheet.dart';

class GiftOption {
  final int id;
  final String name;
  final String icon;
  final String? iconUrl;
  final String? animationUrl;
  final int coinCost;
  final Color color;
  final String animationType;

  const GiftOption({
    required this.id,
    required this.name,
    required this.icon,
    this.iconUrl,
    this.animationUrl,
    required this.coinCost,
    required this.color,
    this.animationType = 'standard',
  });

  factory GiftOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Gift';
    final price = (json['coin_price'] as num?)?.toInt() ?? 50;
    final iconUrl = json['icon_url']?.toString();

    // Assign emoji and color based on name/category
    String emoji = '🎁';
    Color col = const Color(0xFFFF9500);
    final lower = name.toLowerCase();

    if (lower.contains('love') || lower.contains('heart')) {
      emoji = '💖';
      col = const Color(0xFFFF2D55);
    } else if (lower.contains('legit')) {
      emoji = '🛡️';
      col = const Color(0xFF00C853);
    } else if (lower.contains('wine') || lower.contains('champagne')) {
      emoji = '🍷';
      col = const Color(0xFF9C27B0);
    } else if (lower.contains('hookup')) {
      emoji = '🔥';
      col = const Color(0xFFFF3D00);
    } else if (lower.contains('ankh')) {
      emoji = '☥';
      col = const Color(0xFFFFD700);
    } else if (lower.contains('party')) {
      emoji = '🎉';
      col = const Color(0xFFFF9500);
    } else if (lower.contains('fatima')) {
      emoji = '🪬';
      col = const Color(0xFF00B0FF);
    } else if (lower.contains('aries')) {
      emoji = '♈';
      col = const Color(0xFFFF5252);
    } else if (lower.contains('taurus')) {
      emoji = '♉';
      col = const Color(0xFFFFB300);
    } else if (lower.contains('gemini')) {
      emoji = '♊';
      col = const Color(0xFFFFEE58);
    } else if (lower.contains('cancer')) {
      emoji = '♋';
      col = const Color(0xFF4FC3F7);
    } else if (lower.contains('leo')) {
      emoji = '♌';
      col = const Color(0xFFFF9800);
    } else if (lower.contains('virgo')) {
      emoji = '♍';
      col = const Color(0xFF81C784);
    } else if (lower.contains('church')) {
      emoji = '⛪';
      col = const Color(0xFF7E57C2);
    } else if (lower.contains('mosque')) {
      emoji = '🕌';
      col = const Color(0xFF26A69A);
    } else if (lower.contains('mentor')) {
      emoji = '🎓';
      col = const Color(0xFF3F51B5);
    } else if (lower.contains('anpu') || lower.contains('anubis')) {
      emoji = '🐺';
      col = const Color(0xFFFF9500);
    } else if (lower.contains('shrine')) {
      emoji = '⛩️';
      col = const Color(0xFFE91E63);
    } else if (lower.contains('master')) {
      emoji = '🗝️';
      col = const Color(0xFFFFD700);
    } else if (lower.contains('thot') || lower.contains('djehuti')) {
      emoji = '📜';
      col = const Color(0xFF00BCD4);
    } else if (lower.contains('king') || lower.contains('crown')) {
      emoji = '👑';
      col = const Color(0xFFFFD700);
    } else if (lower.contains('cruise') || lower.contains('ship')) {
      emoji = '🚢';
      col = const Color(0xFF0288D1);
    } else if (lower.contains('mansion') || lower.contains('castle')) {
      emoji = '🏰';
      col = const Color(0xFFD4AF37);
    }

    String animType = json['animation_type']?.toString() ?? '';
    if (animType.isEmpty) {
      if (price >= 1000) {
        animType = 'full_screen';
      } else if (price >= 400) {
        animType = 'premium';
      } else if (price <= 20) {
        animType = 'micro';
      } else {
        animType = 'standard';
      }
    }

    return GiftOption(
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: name,
      icon: emoji,
      iconUrl: iconUrl,
      animationUrl: json['animation_url']?.toString(),
      coinCost: price,
      color: col,
      animationType: animType,
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
    GiftOption(id: 1, name: 'Love', icon: '💖', iconUrl: '/gifts/love.png', coinCost: 10, color: Color(0xFFFF2D55), animationType: 'micro'),
    GiftOption(id: 2, name: 'Legit', icon: '🛡️', iconUrl: '/gifts/legit.png', coinCost: 20, color: Color(0xFF00C853), animationType: 'micro'),
    GiftOption(id: 3, name: 'Wine', icon: '🍷', iconUrl: '/gifts/wine.png', coinCost: 25, color: Color(0xFF9C27B0), animationType: 'standard'),
    GiftOption(id: 4, name: 'Hookup', icon: '🔥', iconUrl: '/gifts/hookup.png', coinCost: 30, color: Color(0xFFFF3D00), animationType: 'standard'),
    GiftOption(id: 5, name: 'Ankh of Life', icon: '☥', iconUrl: '/gifts/ankh.png', coinCost: 50, color: Color(0xFFFFD700), animationType: 'standard'),
    GiftOption(id: 6, name: 'Party Time', icon: '🎉', iconUrl: '/gifts/party.png', coinCost: 50, color: Color(0xFFFF9500), animationType: 'standard'),
    GiftOption(id: 7, name: 'Anpu', icon: '🐺', iconUrl: '/gifts/anpu.png', coinCost: 250, color: Color(0xFFFF9500), animationType: 'premium'),
    GiftOption(id: 8, name: 'Master Key', icon: '🗝️', iconUrl: '/gifts/master.png', coinCost: 500, color: Color(0xFFFFD700), animationType: 'premium'),
    GiftOption(id: 9, name: 'King', icon: '👑', iconUrl: '/gifts/king.png', coinCost: 5000, color: Color(0xFFFFD700), animationType: 'exclusive'),
    GiftOption(id: 10, name: 'Cruise', icon: '🚢', iconUrl: '/gifts/cruise.png', coinCost: 7500, color: Color(0xFF0288D1), animationType: 'exclusive'),
    GiftOption(id: 11, name: 'Mansion', icon: '🏰', iconUrl: '/gifts/mansion.png', coinCost: 10000, color: Color(0xFFD4AF37), animationType: 'exclusive'),
  ];

  List<GiftOption> _systemGifts = _defaultGifts;
  GiftOption? _selectedGift;
  bool _loadingGifts = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selectedGift = _defaultGifts[0]; // Love by default
    _fetchSystemGifts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).refresh();
      ref.read(authProvider.notifier).refreshProfile();
    });
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

  int _getUserCoinBalance() {
    final walletState = ref.watch(walletProvider);
    final authState = ref.watch(authProvider);
    if (walletState.wallets.isNotEmpty) {
      return walletState.coinsBalance;
    }
    return authState.user?.coins ?? 0;
  }

  void _showInsufficientCoinsSheet(GiftOption gift, int currentCoins) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        final deficit = gift.coinCost - currentCoins;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFF9500), size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Insufficient Coins',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'You need ${gift.coinCost} Coins to send ${gift.name}, but you currently have $currentCoins Coins (need $deficit more Coins).\n\nTop up your System Wallet to purchase coins and send your gift.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    WalletSheet.show(context);
                  },
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: const Text('Go to Wallet & Deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendGift() async {
    final gift = _selectedGift;
    if (gift == null) return;

    final currentCoins = _getUserCoinBalance();
    if (currentCoins < gift.coinCost) {
      _showInsufficientCoinsSheet(gift, currentCoins);
      return;
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      if (widget.recipientId != null) {
        await ApiClient.instance.dio.post('/gifts/send', data: {
          'gift_id': gift.id,
          'recipient_id': widget.recipientId,
          if (widget.communityId != null) 'community_id': widget.communityId,
          'wallet_type': 'system',
          'idempotency_key': ApiClient.generateIdempotencyKey(),
        });
      }

      // Refresh wallet & auth after sending
      ref.read(walletProvider.notifier).refresh();
      ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        setState(() => _sending = false);

        // Trigger full celebration animation across the screen
        ref.read(giftAnimationProvider.notifier).play(
          GiftAnimationData(
            giftName: gift.name,
            iconUrl: ApiClient.resolveUrl(gift.iconUrl),
            iconEmoji: gift.icon,
            coinPrice: gift.coinCost,
            senderName: 'You',
            recipientName: widget.recipientName,
            animationType: gift.animationType,
          ),
        );

        widget.onGiftSent?.call(gift, gift.coinCost);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${gift.icon} ${gift.name} sent to ${widget.recipientName}!'),
            backgroundColor: gift.color,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        final data = e.response?.data;
        final msg = (data is Map<String, dynamic>)
            ? (data['message'] as String? ?? 'Could not send gift.')
            : 'Could not send gift.';

        if (e.response?.statusCode == 422 || msg.toLowerCase().contains('insufficient')) {
          _showInsufficientCoinsSheet(gift, currentCoins);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final currentCoins = _getUserCoinBalance();
    final hasEnoughCoins = _selectedGift == null || currentCoins >= _selectedGift!.coinCost;

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
                backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.15),
                backgroundImage: widget.recipientAvatar != null && widget.recipientAvatar!.isNotEmpty
                    ? NetworkImage(widget.recipientAvatar!)
                    : null,
                child: widget.recipientAvatar == null || widget.recipientAvatar!.isEmpty
                    ? const Icon(Icons.person, color: Color(0xFFFF9500), size: 22)
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
              // Live Coin Balance & Quick Top Up
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  WalletSheet.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Color(0xFFFF9500), size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '$currentCoins',
                        style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.add_circle_rounded, color: Color(0xFF007AFF), size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Gift Pack', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/wallet');
                },
                child: const Text(
                  'Manage Wallet →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Gift Packs Horizontal Tray with Real Images
          _loadingGifts
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              : SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _systemGifts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      final gift = _systemGifts[idx];
                      final isSelected = _selectedGift?.id == gift.id;
                      final resolvedUrl = ApiClient.resolveUrl(gift.iconUrl);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedGift = gift);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 88,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? gift.color.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? gift.color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (resolvedUrl != null && resolvedUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: resolvedUrl,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) => const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9500)),
                                  ),
                                  errorWidget: (_, _, _) => Text(gift.icon, style: const TextStyle(fontSize: 26)),
                                )
                              else
                                Text(gift.icon, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                gift.name,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${gift.coinCost} coins',
                                style: TextStyle(fontSize: 10, color: gift.color, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 20),

          // Send / Top-Up Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnoughCoins
                    ? (_selectedGift?.color ?? const Color(0xFFFF9500))
                    : const Color(0xFF007AFF),
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
                        Text(hasEnoughCoins ? (_selectedGift?.icon ?? '🎁') : '💳', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          hasEnoughCoins
                              ? 'Send ${_selectedGift?.name ?? 'Gift'} (${_selectedGift?.coinCost ?? 0} Coins)'
                              : 'Top Up Wallet to Send (${_selectedGift?.coinCost ?? 0} Coins)',
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
