import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/security_provider.dart';
import '../core/design_tokens.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Privacy'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'App Lock',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: DesignTokens.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable App Lock'),
            subtitle: const Text('Require a PIN to open MurihSpace'),
            value: security.isPinSet,
            onChanged: (val) {
              if (val) {
                context.push('/profile/security/setup-pin');
              } else {
                _showDisablePinDialog(context, ref);
              }
            },
          ),
          if (security.isPinSet) ...[
            ListTile(
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/profile/security/setup-pin');
              },
            ),
            SwitchListTile(
              title: const Text('Unlock with Biometrics'),
              subtitle: const Text('Use FaceID or Fingerprint to unlock'),
              value: security.useBiometrics,
              onChanged: (val) {
                ref.read(securityProvider.notifier).setUseBiometrics(val);
              },
            ),
            ListTile(
              title: const Text('Auto-Lock Timeout'),
              subtitle: Text(_formatTimeout(security.lockTimeoutMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showTimeoutDialog(context, ref, security.lockTimeoutMinutes);
              },
            ),
          ],
          
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Two-Step Verification',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: DesignTokens.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'When App Lock is enabled, MurihSpace will occasionally ask for your PIN to help you remember it, even if you are actively using the app.',
              style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
            ),
          ),
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

  void _showDisablePinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable App Lock?'),
        content: const Text('This will remove your PIN and disable biometrics.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(securityProvider.notifier).removePin();
              Navigator.pop(ctx);
            },
            child: const Text('Disable', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
