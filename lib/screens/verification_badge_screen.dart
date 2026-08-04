import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../providers/verification_badge_provider.dart';

/// Paid verification badge (Sprint 2 logic): status, apply, renew.
class VerificationBadgeScreen extends ConsumerWidget {
  const VerificationBadgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationBadgeProvider);
    final notifier = ref.read(verificationBadgeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Badge')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, ref, state, notifier),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    VerificationBadgeState state,
    VerificationBadgeNotifier notifier,
  ) {
    if (state.loading && state.status == null) {
      return const LoadingStateWidget(message: 'Loading badge status…');
    }
    if (state.error != null && state.status == null) {
      return ErrorStateWidget(
        title: 'Could not load badge status',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }
    final status = state.status;
    if (status == null) {
      return const ErrorStateWidget(
        title: 'No badge status',
        description: 'Please try again.',
      );
    }

    final active = status.isActive;
    final pending = status.isPending;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  active ? Icons.verified : Icons.verified_outlined,
                  size: 56,
                  color: active ? DesignTokens.primary : DesignTokens.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verification Badge',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: Text(_statusLabel(status.status)),
                  backgroundColor: _statusColor(status.status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _statusColor(status.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Monthly fee: ${_formatMoney(status.monthlyFee)}',
                  style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                ),
                if (!status.kycVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'KYC verification is required before applying for the paid badge.',
                      style: TextStyle(fontSize: 13, color: DesignTokens.warning),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!active && !pending)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.loading
                  ? null
                  : () => _run(context, ref, notifier.apply, 'Applied for the badge!'),
              child: state.loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply for Badge'),
            ),
          ),
        if (active) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.loading ? null : () => _run(context, ref, notifier.renew, 'Badge renewed!'),
              child: const Text('Renew Badge'),
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
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Your badge application is being reviewed.',
              style: TextStyle(fontSize: 13, color: DesignTokens.warning),
            ),
          ),
        ],
      ],
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
}
