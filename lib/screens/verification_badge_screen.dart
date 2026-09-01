import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/verification_badge_provider.dart';

class VerificationBadgeScreen extends ConsumerStatefulWidget {
  const VerificationBadgeScreen({super.key});

  @override
  ConsumerState<VerificationBadgeScreen> createState() => _VerificationBadgeScreenState();
}

class _VerificationBadgeScreenState extends ConsumerState<VerificationBadgeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starAnim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  String _billingCycle = 'annual'; // 'monthly' | 'annual'

  @override
  void dispose() {
    _starAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationBadgeProvider);
    final notifier = ref.read(verificationBadgeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'MurihSpace Premium',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, ref, state, notifier, isDark),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    VerificationBadgeState state,
    VerificationBadgeNotifier notifier,
    bool isDark,
  ) {
    if (state.loading && state.status == null) {
      return const LoadingStateWidget(message: 'Loading Premium status…');
    }
    if (state.error != null && state.status == null) {
      return ErrorStateWidget(
        title: 'Could not load status',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }
    final status = state.status;
    final active = status?.isActive ?? false;
    final pending = status?.isPending ?? false;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 3D Animated Star & Hero Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              RotationTransition(
                turns: _starAnim,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFFF2D55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const BrandIcon(size: 52),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MurihSpace Premium',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unlock exclusive badges, 4GB uploads, and creator tools',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // Monthly vs Annual Segmented Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _billingCycle = 'annual'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _billingCycle == 'annual'
                                ? const Color(0xFF007AFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Annual (Save 33%)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _billingCycle == 'annual' ? Colors.white : (isDark ? Colors.grey[400] : Colors.black),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$39.99 / year',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingCycle == 'annual' ? Colors.white70 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _billingCycle = 'monthly'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _billingCycle == 'monthly'
                                ? const Color(0xFF007AFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Monthly',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _billingCycle == 'monthly' ? Colors.white : (isDark ? Colors.grey[400] : Colors.black),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$4.99 / month',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingCycle == 'monthly' ? Colors.white70 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Features List Group
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INCLUDED BENEFITS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _featureRow('Official Blue Checkmark badge on your profile', isDark),
              const Divider(height: 20),
              _featureRow('Priority placement in community & discover search', isDark),
              const Divider(height: 20),
              _featureRow('Exclusive access to send gifts & custom sticker packs', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (status != null && !active && !pending && status.status != 'not_applied') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9500)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Current Badge Status: ${status.status.toUpperCase().replaceAll('_', ' ')}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFF9500)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (!active && !pending)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: state.loading
                  ? null
                  : () => _handleApplyPressed(context, ref, notifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: state.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Apply for Badge',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        if (active) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: state.loading ? null : () => _run(context, ref, notifier.renew, 'Badge renewed!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Renew Badge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Auto-renew is managed from the platform settings.',
              style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
            ),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF9500), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF9500), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Application In Progress ⏳',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF9500)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Blue Badge application & fee payment are being processed by the verification team (24 hours to 3 business days).',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _handleApplyPressed(BuildContext context, WidgetRef ref, VerificationBadgeNotifier notifier) {
    final user = ref.read(authProvider).user;
    final kycStatus = user?.kycStatus ?? 'unsubmitted';

    // Rule 1: Check KYC Verification Status
    if (kycStatus != 'approved' && kycStatus != 'verified') {
      _showKycPromptSheet(context);
      return;
    }

    // Rule 2: Fee Payment Sheet ($14.99 Admin Fee)
    _showPaymentFeeSheet(context, ref, notifier);
  }

  void _showKycPromptSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF007AFF)),
              ),
              const SizedBox(height: 16),
              Text(
                'KYC Verification Required',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 10),
              Text(
                'Before applying for the official Blue Checkmark Verification Badge, your identity must be verified via Government ID (KYC).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/kyc');
                },
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Complete KYC Verification Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentFeeSheet(BuildContext context, WidgetRef ref, VerificationBadgeNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final feeText = _billingCycle == 'annual' ? '\$39.99 / year' : '\$4.99 / month';

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF007AFF)),
              ),
              const SizedBox(height: 16),
              Text(
                'Verification Badge Fee Payment',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Admin verification review fee: $feeText.\n\nOnce paid, your application enters processing state (24 hours to 3 business days).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _run(context, ref, () => notifier.apply(billingCycle: _billingCycle), 'Application submitted & fee paid!');
                },
                icon: const Icon(Icons.payment_rounded),
                label: Text('Pay $feeText & Submit Application', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function() action,
    String success,
  ) async {
    final ok = await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? success
              : ref.read(verificationBadgeProvider).error ?? 'Action failed.',
        ),
      ),
    );
  }

  String _formatMoney(int minorUnits) {
    final syms = {'NGN': '₦', 'USD': r'$', 'GBP': '£', 'EUR': '€'};
    final sym = syms['NGN'] ?? '';
    return '$sym${(minorUnits / 100).toStringAsFixed(2)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_applied':
        return 'NOT APPLIED';
      case 'payment_pending':
        return 'PAYMENT PENDING';
      case 'kyc_pending':
        return 'KYC PENDING';
      case 'under_review':
        return 'UNDER REVIEW';
      case 'verified':
      case 'active':
        return 'VERIFIED';
      case 'rejected':
        return 'REJECTED';
      case 'suspended':
        return 'SUSPENDED';
      case 'revoked':
        return 'REVOKED';
      case 'expired':
        return 'EXPIRED';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
      case 'active':
        return DesignTokens.success;
      case 'rejected':
      case 'revoked':
        return DesignTokens.danger;
      case 'suspended':
      case 'expired':
        return DesignTokens.warning;
      default:
        return DesignTokens.textSecondary;
    }
  }
  Widget _featureRow(String title, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
