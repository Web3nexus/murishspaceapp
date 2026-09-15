import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play Store & International Financial Regulations Compliant
/// Terms of Service & Privacy Policy Acceptance Modal for MurihSpace Wallet.
class WalletTermsDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const WalletTermsDialog({super.key, required this.onAccept});

  static const String prefKey = 'murih_wallet_terms_accepted_v1';

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> show(BuildContext context, {required VoidCallback onAccept}) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletTermsDialog(onAccept: onAccept),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header with Shield & Verified FinTech Icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MurihSpace Wallet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terms of Use & Escrow Protection Policy',
                      style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Legal clauses scroll box
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF38383A) : const Color(0xFFE2E8F0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legalSection(
                    title: '1. Financial Services & Asset Custody',
                    content: 'MurihSpace provides escrow settlement, peer-to-peer transfers, and virtual digital asset (MSH Coins) services in accordance with global financial regulatory standards. Your fiat balances and transactions are processed through certified PCI-DSS Level 1 compliant gateway partners.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _legalSection(
                    title: '2. Escrow Protection & Contract Release',
                    content: 'Funds locked in Escrow Transactions, Brand Deals, and Marketplace orders are safely quarantined. Releases occur automatically upon verified milestone fulfillment or confirmed buyer acceptance. In the event of dispute, neutral arbitration is executed.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _legalSection(
                    title: '3. Identity Verification & Anti-Fraud (KYC/AML)',
                    content: 'To prevent money laundering, fraud, and terrorism financing, higher tier transactions may require government-issued photo ID verification. Suspicious activities and unauthorized device logins are subject to instant freeze.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _legalSection(
                    title: '4. Virtual Coins & Gifting',
                    content: 'MSH Coins are in-app digital assets used for tipping, gifting, and community support. Coins purchased are non-refundable except where mandated by applicable consumer protection laws.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _legalSection(
                    title: '5. Account Security & Biometrics',
                    content: 'You are responsible for keeping your PIN, biometric passkeys, and two-factor SMS/OTP credentials secure. MurihSpace staff will never request your passwords or one-time verification codes.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Compliance badge
          Row(
            children: [
              const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF34C759)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compliant with Google Financial Services & Privacy Policies',
                  style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Accept & Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(prefKey, true);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  onAccept();
                }
              },
              child: const Text(
                'I Agree & Activate Wallet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalSection({
    required String title,
    required String content,
    required Color textPrimary,
    required Color? textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
          ),
          const SizedBox(height: 3),
          Text(
            content,
            style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

