import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_bottom_sheet.dart';
import '../core/content_moderation_service.dart';
import '../core/design_tokens.dart';
import '../providers/admin_moderation_provider.dart';

/// Admin & Staff CMS Financial Monitoring, Content Moderation & Policy Enforcement Center.
class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final TextEditingController _wordController = TextEditingController();
  String _txFilter = 'All';

  @override
  void dispose() {
    _tab.dispose();
    _wordController.dispose();
    super.dispose();
  }

  void _addWordModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
        final textPrimary = isDark ? DesignTokens.darkTextPrimary : DesignTokens.lightTextPrimary;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Banned Keyword',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wordController,
                autofocus: true,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter keyword or phrase...',
                  filled: true,
                  fillColor: isDark ? DesignTokens.darkSurfaceSecondary : DesignTokens.lightSurfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final word = _wordController.text.trim();
                    if (word.isNotEmpty) {
                      ref.read(adminModerationProvider.notifier).addBannedWord(word);
                      _wordController.clear();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added "$word" to banned words list.')),
                      );
                    }
                  },
                  child: const Text('Add Banned Keyword', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moderationState = ref.watch(adminModerationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final filteredTx = moderationState.transactions.where((t) {
      if (_txFilter == 'Flagged') return t.status == 'flagged_suspicious';
      if (_txFilter == 'High Value') return t.isHighValue;
      if (_txFilter == 'Disputed') return t.status == 'disputed';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFF3B30), size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Staff & Admin CMS',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: const Color(0xFFFF3B30),
          unselectedLabelColor: textSecondary,
          indicatorColor: const Color(0xFFFF3B30),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: 'Financial Monitor (${moderationState.transactions.length})'),
            Tab(text: 'Flagged Accounts (${moderationState.violations.length})'),
            Tab(text: 'Banned Words (${moderationState.bannedWords.length})'),
            const Tab(text: 'Community Guidelines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Tab 1: Financial Monitor (Gifts & Wallet) ────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _filterChip('All', _txFilter == 'All', isDark),
                  const SizedBox(width: 8),
                  _filterChip('Flagged', _txFilter == 'Flagged', isDark),
                  const SizedBox(width: 8),
                  _filterChip('High Value', _txFilter == 'High Value', isDark),
                  const SizedBox(width: 8),
                  _filterChip('Disputed', _txFilter == 'Disputed', isDark),
                ],
              ),
              const SizedBox(height: 16),
              ...filteredTx.map((tx) => _buildTransactionMonitorCard(tx, isDark)),
            ],
          ),

          // ── Tab 2: Flagged Accounts & Violations ──────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFFF3B30), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto-Policy Enforcement Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                          Text('The system auto-scans text, chat messages, and transactions against community guidelines.', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...moderationState.violations.map((v) => _buildViolationCard(v, moderationState, isDark)),
            ],
          ),

          // ── Tab 3: Banned Words & Keyword Rules ───────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prohibited Keyword Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _addWordModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Word', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moderationState.bannedWords.map((word) {
                  return Chip(
                    backgroundColor: cardBg,
                    side: BorderSide(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6)),
                    avatar: const Icon(Icons.block_rounded, color: Color(0xFFFF3B30), size: 16),
                    label: Text(word, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                    deleteIcon: const Icon(Icons.cancel_rounded, size: 18),
                    onDeleted: () {
                      ref.read(adminModerationProvider.notifier).removeBannedWord(word);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed "$word" from banned list')),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Tab 4: Community Guidelines & Admin Settings ────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Admin Brand Deal Deposit & Fee Settings Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFFF9500), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text('Brand Deal Fee & Deposit Controls', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Commitment Deposit Required: ${moderationState.commitmentDepositPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    Slider(
                      value: moderationState.commitmentDepositPercentage,
                      min: 10,
                      max: 100,
                      divisions: 9,
                      activeColor: const Color(0xFFFF9500),
                      label: '${moderationState.commitmentDepositPercentage.toStringAsFixed(0)}%',
                      onChanged: (val) {
                        ref.read(adminModerationProvider.notifier).updateBrandDealSettings(depositPct: val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Platform Escrow Service Fee: ${moderationState.brandDealEscrowFeePercentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    Slider(
                      value: moderationState.brandDealEscrowFeePercentage,
                      min: 1.0,
                      max: 15.0,
                      divisions: 14,
                      activeColor: const Color(0xFF007AFF),
                      label: '${moderationState.brandDealEscrowFeePercentage.toStringAsFixed(1)}%',
                      onChanged: (val) {
                        ref.read(adminModerationProvider.notifier).updateBrandDealSettings(feePct: val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPolicySection(
                '1. Anti-Fraud & Scam Policy',
                'MurihSpace strictly prohibits all forms of fraudulent activities, fake payment proofs, off-platform payment solicitations, and deceptive schemes. All transactions must pass through MurihSpace Escrow.',
                Icons.security_rounded,
                const Color(0xFF007AFF),
                cardBg,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 12),
              _buildPolicySection(
                '2. Financial Escrow Rules',
                'Funds for vendor orders and brand deal creator sponsorships are held securely in Escrow until fulfillment is verified. Disputed orders undergo mandatory staff review before release.',
                Icons.account_balance_wallet_rounded,
                const Color(0xFF34C759),
                cardBg,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 12),
              _buildPolicySection(
                '3. Content & Harassment Standards',
                'Hate speech, harassment, fake products, and illegal goods are strictly forbidden. Accounts violating these standards will be automatically flagged and subject to immediate suspension by Staff.',
                Icons.gavel_rounded,
                const Color(0xFFFF9500),
                cardBg,
                textPrimary,
                textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _txFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF3B30)
              : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionMonitorCard(AdminTransactionRecord tx, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final isFlagged = tx.status == 'flagged_suspicious';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: isFlagged ? Border.all(color: const Color(0xFFFF3B30), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isFlagged ? const Color(0xFFFF3B30) : const Color(0xFF007AFF)).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFlagged ? Icons.warning_amber_rounded : Icons.receipt_long_rounded,
                  color: isFlagged ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.user, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                    Text('${tx.type} · ID: ${tx.id}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Text(
                tx.amount,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF007AFF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFlagged
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                      : const Color(0xFF34C759).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tx.status.toUpperCase(),
                  style: TextStyle(
                    color: isFlagged ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      side: const BorderSide(color: Color(0xFFFF3B30)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Transaction ${tx.id} flagged for security audit.')),
                      );
                    },
                    child: const Text('Flag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViolationCard(ContentViolation v, AdminModerationState state, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final isUserDisabled = state.disabledUserIds.contains(v.userId);
    final isWalletFrozen = state.frozenWalletUserIds.contains(v.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFF3B30),
                child: Text(v.userName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${v.userName} (${v.userHandle})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                    Text('Violation in ${v.contentType.toUpperCase()}', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${v.severity.name.toUpperCase()} (${v.riskScore}%)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '"${v.originalContent}"',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: v.matchedBannedWords.map((w) {
              return Chip(
                backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                label: Text('Matched: $w', style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUserDisabled ? Colors.grey : const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isUserDisabled
                      ? null
                      : () {
                          ref.read(adminModerationProvider.notifier).disableAccount(v.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Account (${v.userName}) has been DISABLED by Admin.'),
                              backgroundColor: const Color(0xFFFF3B30),
                            ),
                          );
                        },
                  child: Text(isUserDisabled ? 'Account Disabled' : 'Disable Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWalletFrozen ? Colors.grey : const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isWalletFrozen
                      ? null
                      : () {
                          ref.read(adminModerationProvider.notifier).freezeWallet(v.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Wallet for (${v.userName}) has been FROZEN.'),
                              backgroundColor: const Color(0xFFFF9500),
                            ),
                          );
                        },
                  child: Text(isWalletFrozen ? 'Wallet Frozen' : 'Freeze Wallet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, String body, IconData icon, Color color, Color cardBg, Color textPrimary, Color? textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
