import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Official Digital Escrow Contract Certificate & Legal Protection Document Dialog.
class BrandDealCertificateDialog extends StatelessWidget {
  final String dealTitle;
  final String brandName;
  final String creatorName;
  final double totalBudget;
  final double depositAmount;
  final double depositPercentage;
  final String deliverables;

  const BrandDealCertificateDialog({
    super.key,
    required this.dealTitle,
    required this.brandName,
    required this.creatorName,
    required this.totalBudget,
    required this.depositAmount,
    required this.depositPercentage,
    required this.deliverables,
  });

  static void show(
    BuildContext context, {
    required String dealTitle,
    required String brandName,
    required String creatorName,
    required double totalBudget,
    required double depositAmount,
    required double depositPercentage,
    required String deliverables,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => BrandDealCertificateDialog(
        dealTitle: dealTitle,
        brandName: brandName,
        creatorName: creatorName,
        totalBudget: totalBudget,
        depositAmount: depositAmount,
        depositPercentage: depositPercentage,
        deliverables: deliverables,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final certId = 'CERT-BD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold Certificate Ribbon Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFFCC00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 6),
                  const Text(
                    'DIGITAL ESCROW CONTRACT CERTIFICATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Legally Binding Protection Guarantee · $certId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Certificate Contract Body
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _certRow('Campaign Title', dealTitle, textPrimary, textSecondary),
                  const Divider(height: 16),
                  _certRow('Sponsoring Brand', brandName, textPrimary, textSecondary),
                  const Divider(height: 16),
                  _certRow('Creator Ambassador', creatorName, textPrimary, textSecondary),
                  const Divider(height: 16),
                  _certRow('Total Campaign Budget', '\$${totalBudget.toStringAsFixed(2)} USD', const Color(0xFF007AFF), textSecondary, isBold: true),
                  const Divider(height: 16),
                  _certRow('Commitment Deposit (${depositPercentage.toStringAsFixed(0)}%)', '\$${depositAmount.toStringAsFixed(2)} USD (LOCKED)', const Color(0xFF34C759), textSecondary, isBold: true),
                  const Divider(height: 16),
                  _certRow('Required Deliverables', deliverables, textPrimary, textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Legal Rights & Terms Clause
            Text(
              'LEGAL PROTECTION & DISPUTE CLAUSE:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '1. Both parties agree to execute deliverables in good faith.\n'
              '2. The upfront deposit is locked in MurihSpace Escrow and cannot be unilaterally withdrawn after creator engagement.\n'
              '3. All copyright rights transfer upon final escrow payment approval.',
              style: TextStyle(fontSize: 11, color: textSecondary, height: 1.35),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'https://murihspace.com/escrow/certificate/$certId'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Certificate link copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Close Certificate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _certRow(String label, String value, Color valColor, Color? lblColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: lblColor, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: valColor,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
