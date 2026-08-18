import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_moderation_provider.dart';

/// Comprehensive Help Center Guide for Brand Deals & Escrow Policies.
class BrandDealsHelpScreen extends ConsumerWidget {
  const BrandDealsHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderation = ref.watch(adminModerationProvider);
    final depositPct = moderation.commitmentDepositPercentage;
    final feePct = moderation.brandDealEscrowFeePercentage;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Brand Deals & Escrow Guide',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Guide Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9500), Color(0xFFFFCC00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_center_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text('HELP CENTER GUIDE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'How Brand Deals & Escrow Protection Work',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete guide for brand sponsors and creator ambassadors on MurihSpace.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section 1: 30% Commitment Deposit Rule
          _buildGuideCard(
            title: '1. Upfront Commitment Deposit (${depositPct.toStringAsFixed(0)}%)',
            body: 'To protect creators from brand ghosting or cancelled negotiations after work begins, all brand sponsors must lock a minimum ${depositPct.toStringAsFixed(0)}% Commitment Deposit upfront into MurihSpace Escrow before posting a campaign live.\n\nOnce locked, this deposit guarantees creator compensation upon deliverable completion.',
            icon: Icons.lock_clock_rounded,
            color: const Color(0xFF007AFF),
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Section 2: Digital Escrow Contract Certificate
          _buildGuideCard(
            title: '2. Digital Contract Certification',
            body: 'Every posted brand deal automatically generates a cryptographic Digital Escrow Contract Certificate (PDF/Document).\n\nThis legally binding document outlines agreed deliverables, payment terms, copyright transfers, and non-disclosure clauses protecting both the brand and creator.',
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF34C759),
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Section 3: Dynamic Platform Fee Structure
          _buildGuideCard(
            title: '3. Transparent Escrow Fee (${feePct.toStringAsFixed(1)}%)',
            body: 'MurihSpace charges a transparent ${feePct.toStringAsFixed(1)}% Escrow Service Fee on completed brand deal transactions.\n\nThis fee covers dispute mediation, contract certification, and secure multi-currency payment processing. (Fee rates can be adjusted by Admin in the Moderation Center).',
            icon: Icons.percent_rounded,
            color: const Color(0xFFFF9500),
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Section 4: Milestone Deliverables & Escrow Release
          _buildGuideCard(
            title: '4. Deliverables Verification & Funds Release',
            body: '1. Creators submit draft video/posts directly in the Brand Deal Hub.\n2. Brand sponsors review and approve deliverables.\n3. Locked escrow funds are instantly released into the creator\'s Wallet.',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF5856D6),
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color textPrimary,
    required Color? textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.45)),
        ],
      ),
    );
  }
}
