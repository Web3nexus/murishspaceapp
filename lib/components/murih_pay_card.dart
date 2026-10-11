import 'package:flutter/material.dart';
import '../providers/wallet_provider.dart';

/// Premium fintech digital payment card matching MurihSpace brand identity (#1A68D4).
/// Showcases Available Balance directly on the card with live country currency conversion,
/// user name and @tag, and clean EMV/contactless presentation.
class MurihPayCard extends StatelessWidget {
  final WalletType walletType;
  final String userName;
  final String userTag;
  final double availableBalance;
  final String currency;
  final String localCurrency;
  final double localRate;
  final String localFormatted;
  final bool isBalanceHidden;
  final bool showLocalCurrency;
  final VoidCallback? onToggleCurrency;

  const MurihPayCard({
    super.key,
    required this.walletType,
    this.userName = 'Vincent Adetuberu',
    this.userTag = '@vincent',
    this.availableBalance = 0.0,
    this.currency = 'USD',
    this.localCurrency = 'NGN',
    this.localRate = 1326.0,
    this.localFormatted = '',
    this.isBalanceHidden = false,
    this.showLocalCurrency = false,
    this.onToggleCurrency,
  });

  String get _walletSubtitle => switch (walletType) {
        WalletType.creator => 'Creator Earnings',
        WalletType.business => 'Business Revenue',
        _ => 'Personal Wallet',
      };

  String _localSymbol(String cur) => switch (cur.toUpperCase()) {
        'NGN' => '₦',
        'GBP' => '£',
        'EUR' => '€',
        'GHS' => 'GH₵',
        'KES' => 'KSh',
        _ => '$cur ',
      };

  String _flag(String cur) => switch (cur.toUpperCase()) {
        'NGN' => '🇳🇬',
        'KES' => '🇰🇪',
        'GHS' => '🇬🇭',
        'GBP' => '🇬🇧',
        'EUR' => '🇪🇺',
        'ZAR' => '🇿🇦',
        'CAD' => '🇨🇦',
        _ => '🇺🇸',
      };

  @override
  Widget build(BuildContext context) {
    final double converted = availableBalance * (localRate > 0 ? localRate : 1.0);
    final String formattedUsd = '\$${availableBalance.toStringAsFixed(2)}';
    final String formattedLocal = localFormatted.isNotEmpty
        ? localFormatted
        : '${_localSymbol(localCurrency)}${converted.toStringAsFixed(2)}';

    final String activeAmount = showLocalCurrency ? formattedLocal : formattedUsd;
    final String activeCurrency = showLocalCurrency ? localCurrency : currency;

    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A68D4),
              Color(0xFF1555AD),
              Color(0xFF0E3D7D),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A68D4).withValues(alpha: 0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Subtle background curves
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardBackgroundPainter(),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Brand Name + Wallet Subtitle badge + Chip + Contactless
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'MurihPay',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _walletSubtitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            _buildEmvChip(),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.contactless_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Middle: Available Balance directly on the card
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AVAILABLE BALANCE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (onToggleCurrency != null && localCurrency != 'USD')
                              GestureDetector(
                                onTap: onToggleCurrency,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        showLocalCurrency ? 'USD' : localCurrency,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              isBalanceHidden ? '••••••••' : activeAmount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              activeCurrency,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (localCurrency != 'USD') ...[
                          const SizedBox(height: 2),
                          Text(
                            isBalanceHidden
                                ? '≈ ••••••••'
                                : (showLocalCurrency
                                    ? '≈ $formattedUsd USD'
                                    : '≈ $formattedLocal $localCurrency · Rate: 1 USD = ${_localSymbol(localCurrency)}${localRate.toStringAsFixed(0)}'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Bottom: User Name / @Tag + Currency Indicator (No Visa logo, no card numbers, no expiry)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACCOUNT HOLDER',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (userTag.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      userTag.startsWith('@') ? userTag : '@$userTag',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Currency indicator pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_flag(activeCurrency), style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                activeCurrency,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmvChip() {
    return Container(
      width: 32,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFDF80),
            Color(0xFFF5B738),
            Color(0xFFD69415),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFC043), width: 0.8),
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB57705), width: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFB57705), width: 0.6),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFB57705), width: 0.6),
                    ),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path1 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.4,
        size.width,
        size.height * 0.7,
      );
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.45, 0)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.6,
        size.width,
        size.height * 0.95,
      );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
