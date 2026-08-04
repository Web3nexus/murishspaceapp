import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';

/// Account upgrade flow (Sprint 1 logic): apply as creator/vendor, view
/// pending application and history, cancel pending applications.
class UpgradeAccountScreen extends ConsumerWidget {
  const UpgradeAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roleUpgradeProvider);
    final notifier = ref.read(roleUpgradeProvider.notifier);
    final role = ref.watch(authProvider).user?.role ?? UserRole.member;

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Account')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, ref, state, notifier, role),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    RoleUpgradeState state,
    RoleUpgradeNotifier notifier,
    UserRole role,
  ) {
    if (state.loading && state.application == null && state.history.isEmpty) {
      return const LoadingStateWidget(message: 'Loading applications…');
    }
    if (state.error != null && state.application == null && state.history.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load applications',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }

    final application = state.application;
    final canApply = Permissions.roleHas(role, 'role.upgrade.apply');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignTokens.navy,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current role: ${role.label}',
                style: const TextStyle(
                  color: DesignTokens.sidebarPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'MurihSpace is free for all users. Upgrade to unlock monetization, storefront and creator tools.',
                style: TextStyle(color: DesignTokens.sidebarForeground, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (application != null && application.status == 'pending') ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule, color: DesignTokens.warning),
              title: const Text('Application pending review'),
              subtitle: Text(
                'You requested an upgrade to ${application.requestedRole}. '
                'KYC may be required before the role activates.',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel application',
                onPressed: () => _confirmCancel(context, ref),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (application != null && application.status == 'rejected') ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.cancel, color: DesignTokens.danger),
              title: const Text('Application not approved'),
              subtitle: Text(
                application.rejectionReason ?? 'Requirements were not met.',
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _RoleUpgradeCard(
          role: UserRole.creator,
          currentRole: role,
          icon: Icons.auto_awesome,
          blurb:
              'Link-in-bio, digital products, courses, coaching, memberships, communities, live sessions and vendor capabilities.',
          loading: state.loading,
          onApply: () => _apply(context, ref, 'creator'),
        ),
        const SizedBox(height: 12),
        _RoleUpgradeCard(
          role: UserRole.vendor,
          currentRole: role,
          icon: Icons.storefront,
          blurb:
              'Physical storefront, inventory, orders, fulfilment, shipping, reviews, disputes and business wallet payouts.',
          loading: state.loading,
          onApply: () => _apply(context, ref, 'vendor'),
        ),
        if (!canApply) ...[
          const SizedBox(height: 12),
          const PermissionDeniedWidget(
            title: 'Role upgrades',
            description: 'Admins manage roles directly.',
          ),
        ],
        if (state.history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Application History',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final record in state.history)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  record.status == 'approved' ? Icons.check_circle : Icons.history,
                  color: record.status == 'approved'
                      ? DesignTokens.success
                      : DesignTokens.textSecondary,
                ),
                title: Text('${record.previousRole} → ${record.requestedRole}'),
                subtitle: Text('Status: ${record.status}'),
                trailing: record.requestedAt != null
                    ? Text(
                        record.requestedAt!.split('T').first,
                        style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                      )
                    : null,
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, String requestedRole) async {
    final ok = await ref.read(roleUpgradeProvider.notifier).apply(requestedRole);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Application submitted for review.'
              : ref.read(roleUpgradeProvider).error ?? 'Could not submit the application.',
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel application?'),
        content: const Text('Your pending role application will be withdrawn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(roleUpgradeProvider.notifier).cancel();
    }
  }
}

class _RoleUpgradeCard extends StatelessWidget {
  final UserRole role;
  final UserRole currentRole;
  final IconData icon;
  final String blurb;
  final bool loading;
  final VoidCallback onApply;

  const _RoleUpgradeCard({
    required this.role,
    required this.currentRole,
    required this.icon,
    required this.blurb,
    required this.loading,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentRole == role;
    final isCovered = role == UserRole.vendor && currentRole == UserRole.creator;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DesignTokens.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: DesignTokens.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${role.label} Role',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (isCurrent)
                  const Chip(
                    label: Text('Active'),
                    backgroundColor: Color(0x1A22A06B),
                    labelStyle: TextStyle(color: DesignTokens.success, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(blurb, style: const TextStyle(fontSize: 13, height: 1.45)),
            const SizedBox(height: 14),
            if (isCurrent)
              const Center(
                child: Text(
                  'You already hold this role',
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                ),
              )
            else if (isCovered)
              const Center(
                child: Text(
                  'Creator role includes all vendor capabilities',
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : onApply,
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Apply as ${role.label}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
