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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Upgrade Account',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, ref, state, notifier, role, isDark),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    RoleUpgradeState state,
    RoleUpgradeNotifier notifier,
    UserRole role,
    bool isDark,
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
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Current Role Banner Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'CURRENT ROLE: ${role.label.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'MurihSpace Power Accounts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upgrade your account to unlock vendor store escrow, brand deal marketplaces, and creator tools.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (application != null && application.status == 'pending') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF9500), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFFF9500), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Application Pending Review',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFFF9500)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requested upgrade to ${application.requestedRole}. KYC verification may be required.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.black87),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFFF9500)),
                  tooltip: 'Cancel application',
                  onPressed: () => _confirmCancel(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Creator Card
        _RoleUpgradeCard(
          role: UserRole.creator,
          currentRole: role,
          icon: Icons.campaign_rounded,
          iconColor: const Color(0xFFFF9500),
          blurb:
              'Brand deals marketplace, creator hubs, link-in-bio, digital products, courses, memberships, and locked escrow payouts.',
          loading: state.loading,
          isDark: isDark,
          cardBg: cardBg,
          onApply: () => _handleRoleApplyWithRetention(context, ref, 'creator', role),
        ),
        const SizedBox(height: 14),

        // Vendor Card
        _RoleUpgradeCard(
          role: UserRole.vendor,
          currentRole: role,
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF5856D6),
          blurb:
              'Physical storefront, inventory management, escrow orders, fulfilment, customer reviews, and direct wallet payouts.',
          loading: state.loading,
          isDark: isDark,
          cardBg: cardBg,
          onApply: () => _handleRoleApplyWithRetention(context, ref, 'vendor', role),
        ),

        if (state.history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'APPLICATION HISTORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.history.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (ctx, i) {
                final record = state.history[i];
                final isApproved = record.status == 'approved';
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isApproved ? const Color(0xFF34C759) : Colors.grey).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved ? Icons.check_circle_rounded : Icons.history_rounded,
                      color: isApproved ? const Color(0xFF34C759) : Colors.grey,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    '${record.previousRole} → ${record.requestedRole}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Status: ${record.status}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Handles role application with role retention check & web access guide modal!
  Future<void> _handleRoleApplyWithRetention(
    BuildContext context,
    WidgetRef ref,
    String targetRole,
    UserRole currentRole,
  ) async {
    // If existing Vendor/Creator, ask retention confirmation
    if (currentRole == UserRole.vendor && targetRole == 'creator') {
      final retain = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Retain Vendor Profile?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
            'You are currently a Vendor. Would you like to retain your Vendor Store & Inventory profile while adding the Creator Hub & Brand Deals profile to manage both?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retain Vendor & Add Creator'),
            ),
          ],
        ),
      );
      if (retain != true) return;
    } else if (currentRole == UserRole.creator && targetRole == 'vendor') {
      final retain = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Retain Creator Profile?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
            'You are currently a Creator. Would you like to retain your Creator Profile while adding Vendor Store & Inventory capabilities?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retain Creator & Add Vendor'),
            ),
          ],
        ),
      );
      if (retain != true) return;
    }

    final ok = await ref.read(roleUpgradeProvider.notifier).apply(targetRole);
    if (!context.mounted) return;

    if (ok) {
      // Show Web Access Guide Dialog Modal
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFF007AFF), size: 28),
              const SizedBox(width: 8),
              const Text('Upgrade Requested!', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your application to upgrade to ${targetRole.toUpperCase()} has been submitted successfully.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🌐 Web Dashboard Access Instructions:',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF007AFF)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Open https://murihspace.com/dashboard/$targetRole on your browser.\n'
                      '2. Log in with your MurihSpace credentials.\n'
                      '3. Access full store analytics, escrow payouts, and campaign management.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got It!'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(roleUpgradeProvider).error ?? 'Could not submit application.',
          ),
        ),
      );
    }
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
  final Color iconColor;
  final String blurb;
  final bool loading;
  final bool isDark;
  final Color cardBg;
  final VoidCallback onApply;

  const _RoleUpgradeCard({
    required this.role,
    required this.currentRole,
    required this.icon,
    required this.iconColor,
    required this.blurb,
    required this.loading,
    required this.isDark,
    required this.cardBg,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentRole == role;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${role.label} Account',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFF34C759),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            blurb,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (isCurrent)
            Center(
              child: Text(
                'You already hold this role active.',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: loading ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Apply as ${role.label}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
