import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../providers/kyc_provider.dart';

/// Screen for displaying KYC status and submitting verification documents.
/// Wired to `/kyc/status` and `/kyc/triggers` (Sprint 2 logic).
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _docController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _docController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kycProvider);
    final notifier = ref.read(kycProvider.notifier);
    final status = state.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification (KYC)')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, state, status, notifier),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    KycState state,
    KycStatusInfo? status,
    KycNotifier notifier,
  ) {
    if (state.loading && status == null) {
      return const LoadingStateWidget(message: 'Loading verification status…');
    }
    if (state.error != null && status == null) {
      return ErrorStateWidget(
        title: 'Could not load verification',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }
    if (status == null) {
      return const ErrorStateWidget(
        title: 'No verification status',
        description: 'Please try again.',
      );
    }

    final triggers = state.triggers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 48, color: DesignTokens.primaryDark),
                const SizedBox(height: 8),
                const Text(
                  'Verification Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(_statusLabel(status.status)),
                  backgroundColor: _statusColor(status.status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _statusColor(status.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (status.isVerified) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'You are verified. No further action is needed.',
                    style: TextStyle(color: DesignTokens.success, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (status.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${status.rejectionReason}',
                    style: const TextStyle(color: DesignTokens.danger, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (triggers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Why verification is needed',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final trigger in triggers)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: DesignTokens.warning),
                title: Text(trigger.title),
                subtitle: Text(trigger.description),
              ),
            ),
        ],
        if (!status.isVerified) ...[
          const SizedBox(height: 24),
          TextFormField(
            controller: _docController,
            decoration: const InputDecoration(
              labelText: 'Passport or ID Reference',
              hintText: 'e.g. PASSPORT-12345678',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _submit(notifier),
            icon: const Icon(Icons.upload_file),
            label: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Verification'),
          ),
        ],
      ],
    );
  }

  Future<void> _submit(KycNotifier notifier) async {
    if (_docController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your document reference.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await notifier.submit(payload: {
      'document_reference': _docController.text.trim(),
      'type': 'identity_document',
    });
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Identity verification document submitted!'
              : ref.read(kycProvider).error ?? 'Submission failed.',
        ),
      ),
    );
    if (ok) _docController.clear();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_required':
        return 'NOT REQUIRED';
      case 'not_started':
        return 'NOT STARTED';
      case 'in_review':
        return 'IN REVIEW';
      case 'verified':
      case 'approved':
        return 'VERIFIED';
      case 'rejected':
        return 'REJECTED';
      case 'expired':
        return 'EXPIRED';
      case 'resubmission_required':
        return 'RESUBMISSION REQUIRED';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
      case 'approved':
        return DesignTokens.success;
      case 'rejected':
        return DesignTokens.danger;
      case 'pending':
      case 'in_review':
      case 'not_started':
      case 'resubmission_required':
        return DesignTokens.warning;
      default:
        return DesignTokens.textSecondary;
    }
  }
}
