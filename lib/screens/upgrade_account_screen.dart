import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../components/app_bottom_sheet.dart';
import '../components/ui_states.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';

/// Account upgrade flow: apply as creator/vendor, view
/// pending application and history, cancel pending applications, and submit KYC when requested.
class UpgradeAccountScreen extends ConsumerWidget {
  const UpgradeAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roleUpgradeProvider);
    final notifier = ref.read(roleUpgradeProvider.notifier);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role ?? UserRole.member;
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
        child: _body(context, ref, state, notifier, user, role, isDark),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    RoleUpgradeState state,
    RoleUpgradeNotifier notifier,
    dynamic user,
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
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Header Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Current Role: ${role.label}',
                      style: const TextStyle(
                        color: Color(0xFFFF9500),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Unlock Pro Tools',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
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
              color: const Color(0xFFFF9500).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF9500), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            'Requested upgrade to ${application.requestedRole}. Our team is reviewing your profile.',
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black38 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Identity Verification (KYC)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.kycStatus == 'verified'
                                  ? 'Identity Verified ✓'
                                  : user?.kycStatus == 'pending'
                                      ? 'KYC Submitted — Under Review'
                                      : 'Submit your government ID to complete your Creator verification.',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      if (user?.kycStatus != 'verified' && user?.kycStatus != 'pending')
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => context.push('/kyc'),
                          child: const Text('Verify →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
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
      final retain = await AppBottomSheet.showConfirmation(
        context: context,
        title: 'Retain Vendor Profile?',
        message: 'You are currently a Vendor. Would you like to retain your Vendor Store & Inventory profile while adding the Creator Hub & Brand Deals profile to manage both?',
        confirmText: 'Retain & Add Creator',
        icon: Icons.storefront_rounded,
      );
      if (retain != true) return;
    } else if (currentRole == UserRole.creator && targetRole == 'vendor') {
      final retain = await AppBottomSheet.showConfirmation(
        context: context,
        title: 'Retain Creator Profile?',
        message: 'You are currently a Creator. Would you like to retain your Creator Profile while adding Vendor Store & Inventory capabilities?',
        confirmText: 'Retain & Add Vendor',
        icon: Icons.palette_rounded,
      );
      if (retain != true) return;
    }

    final ok = await ref.read(roleUpgradeProvider.notifier).apply(targetRole);
    if (!context.mounted) return;

    if (ok) {
      await AppBottomSheet.showNotice(
        context: context,
        title: 'Upgrade Requested!',
        message: 'Your application to upgrade to ${targetRole.toUpperCase()} has been submitted successfully.\n\n🌐 Web Dashboard Access:\n1. Open https://murihspace.com/dashboard/$targetRole on your browser.\n2. Log in with your MurihSpace credentials.\n3. Access full store analytics, escrow payouts, and campaign management.',
        actionText: 'Got It!',
        customIconWidget: const BrandFavicon(size: 32),
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
    final confirmed = await AppBottomSheet.showConfirmation(
      context: context,
      title: 'Cancel Application?',
      message: 'Your pending role application will be withdrawn.',
      confirmText: 'Withdraw Application',
      isDestructive: true,
      icon: Icons.cancel_outlined,
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
