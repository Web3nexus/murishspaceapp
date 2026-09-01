import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/app_bottom_sheet.dart';
import '../components/transaction_pin_dialog.dart';
import '../core/permissions_service.dart';
import '../providers/security_provider.dart';
import '../core/design_tokens.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final permissions = ref.watch(permissionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Permissions'),
      ),
      body: ListView(
        children: [
          // ── App Lock Section ──────────────────────────────────
          _SectionHeader(title: 'App Lock & Biometrics'),
          SwitchListTile(
            title: const Text('Enable App PIN Lock'),
            subtitle: Text(security.isPinSet ? 'PIN Enabled' : 'No PIN setup'),
            value: security.isPinSet,
            activeColor: const Color(0xFFF09A3E),
            onChanged: (val) {
              if (val) {
                context.push('/settings/security/setup-pin');
              } else {
                _showDisablePinDialog(context, ref);
              }
            },
          ),
          if (security.isPinSet) ...[
            SwitchListTile(
              title: Text('Use ${security.biometricLabel}'),
              subtitle: Text('Unlock app using ${security.biometricLabel}'),
              value: security.useBiometrics,
              activeColor: const Color(0xFFF09A3E),
              onChanged: (val) {
                ref.read(securityProvider.notifier).setUseBiometrics(val);
              },
            ),
            ListTile(
              title: const Text('Auto-Lock Timeout'),
              subtitle: Text(_formatTimeout(security.lockTimeoutMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimeoutDialog(context, ref, security.lockTimeoutMinutes),
            ),
          ],

          const Divider(height: 32),

          // ── Transaction PIN Section ───────────────────────────
          _SectionHeader(title: 'Payments & Transactions PIN'),
          ListTile(
            title: Text(security.isTransactionPinSet
                ? 'Change Transaction PIN'
                : 'Setup Transaction PIN'),
            subtitle: Text(security.isTransactionPinSet
                ? 'Used for wallet transfers, gift sending & payouts'
                : 'Require a separate PIN for all financial actions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final isVerified = !security.isTransactionPinSet ||
                  await TransactionPinDialog.show(
                    context,
                    title: 'Current PIN Required',
                    description: 'Verify your existing transaction PIN first.',
                  );
              if (isVerified && context.mounted) {
                context.push('/settings/security/setup-pin');
              }
            },
          ),

          const Divider(height: 32),

          // ── Native Permissions Section ────────────────────────
          _SectionHeader(title: 'Native Device Permissions'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFFF09A3E)),
            title: const Text('Push & In-App Notifications'),
            subtitle: Text(permissions.notificationsGranted ? 'Allowed' : 'Tap to enable'),
            trailing: Icon(
              permissions.notificationsGranted ? Icons.check_circle_rounded : Icons.chevron_right,
              color: permissions.notificationsGranted ? Colors.green : null,
            ),
            onTap: () {
              ref.read(permissionsProvider.notifier).showPermissionRationaleSheet(
                context: context,
                title: 'Enable Notifications',
                description: 'Stay updated when fans send gifts, reply in threads, or when creators start live audio sessions.',
                icon: Icons.notifications_active_rounded,
                type: AppPermissionType.notifications,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFF09A3E)),
            title: const Text('Camera Access'),
            subtitle: Text(permissions.cameraGranted ? 'Allowed' : 'Tap to enable'),
            trailing: Icon(
              permissions.cameraGranted ? Icons.check_circle_rounded : Icons.chevron_right,
              color: permissions.cameraGranted ? Colors.green : null,
            ),
            onTap: () {
              ref.read(permissionsProvider.notifier).showPermissionRationaleSheet(
                context: context,
                title: 'Enable Camera',
                description: 'Required to take photos, scan QR codes, and participate in LiveKit video calls.',
                icon: Icons.camera_alt_rounded,
                type: AppPermissionType.camera,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mic_outlined, color: Color(0xFFF09A3E)),
            title: const Text('Microphone Access'),
            subtitle: Text(permissions.microphoneGranted ? 'Allowed' : 'Tap to enable'),
            trailing: Icon(
              permissions.microphoneGranted ? Icons.check_circle_rounded : Icons.chevron_right,
              color: permissions.microphoneGranted ? Colors.green : null,
            ),
            onTap: () {
              ref.read(permissionsProvider.notifier).showPermissionRationaleSheet(
                context: context,
                title: 'Enable Microphone',
                description: 'Required to record voice notes and speak in live audio rooms.',
                icon: Icons.mic_rounded,
                type: AppPermissionType.microphone,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFF09A3E)),
            title: const Text('Photos & Media Library'),
            subtitle: Text(permissions.photosGranted ? 'Allowed' : 'Tap to enable'),
            trailing: Icon(
              permissions.photosGranted ? Icons.check_circle_rounded : Icons.chevron_right,
              color: permissions.photosGranted ? Colors.green : null,
            ),
            onTap: () {
              ref.read(permissionsProvider.notifier).showPermissionRationaleSheet(
                context: context,
                title: 'Enable Media Access',
                description: 'Required to select photos and videos to share with your audience and friends.',
                icon: Icons.photo_library_rounded,
                type: AppPermissionType.photos,
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatTimeout(int minutes) {
    if (minutes == 0) return 'Immediately';
    if (minutes == 1) return 'After 1 minute';
    if (minutes == 1440) return 'Daily Unlock (Every 24 Hours)';
    return 'After $minutes minutes';
  }

  void _showDisablePinDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await AppBottomSheet.showConfirmation(
      context: context,
      title: 'Disable App Lock?',
      message: 'This will remove your PIN and disable biometrics.',
      confirmText: 'Disable',
      isDestructive: true,
      icon: Icons.lock_open_rounded,
    );

    if (confirm == true) {
      ref.read(securityProvider.notifier).removePin();
    }
  }

  void _showTimeoutDialog(BuildContext context, WidgetRef ref, int current) {
    final options = [
      {'label': 'Immediately', 'value': 0},
      {'label': 'After 1 minute', 'value': 1},
      {'label': 'After 15 minutes', 'value': 15},
      {'label': 'After 1 hour', 'value': 60},
      {'label': 'Daily Unlock (Every 24 Hours)', 'value': 1440},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Auto-Lock Timeout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...options.map((opt) {
                return RadioListTile<int>(
                  title: Text(opt['label'] as String),
                  value: opt['value'] as int,
                  groupValue: current,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(securityProvider.notifier).setLockTimeout(val);
                    }
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
