import 'package:flutter/material.dart';
import '../providers/wallet_provider.dart';

/// Premium fintech digital payment card matching MurihSpace brand identity (#1A68D4).
class MurihPayCard extends StatelessWidget {
  final WalletType walletType;
  final String cardholderName;
  final String maskedNumber;
  final String expiry;
  final bool isBalanceHidden;

  const MurihPayCard({
    super.key,
    required this.walletType,
    this.cardholderName = 'VINCENT ADETUBERU',
    this.maskedNumber = '5495 7381 3759 2321',
    this.expiry = '09/28',
    this.isBalanceHidden = false,
  });

  String get _walletSubtitle => switch (walletType) {
        WalletType.creator => 'Creator Earnings',
        WalletType.business => 'Business Revenue',
        _ => 'Personal Wallet',
      };

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Brand Name & Contactless
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            const SizedBox(height: 2),
                            Text(
                              _walletSubtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Contactless wave symbol
                        Icon(
                          Icons.contactless_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 26,
                        ),
                      ],
                    ),

                    // Middle: EMV Chip graphic
                    _buildEmvChip(),

                    // Bottom: Number, Holder Name, Expiry, Logo
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Number
                        Text(
                          isBalanceHidden ? '•••• •••• •••• ••••' : maskedNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Cardholder name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CARDHOLDER',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    cardholderName.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Expiry
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VALID',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    expiry,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Visa watermark mark
                            const Text(
                              'VISA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
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
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFDF80),
            Color(0xFFF5B738),
            Color(0xFFD69415),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFC043), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 32,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.25),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Container(
              width: 0.8,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Container(
              width: 0.8,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 15,
            child: Container(
              height: 0.8,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.4, size.width, size.height * 0.6);

    final path2 = Path()
      ..moveTo(size.width * 0.4, 0)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.5, size.width, size.height * 0.8);

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
