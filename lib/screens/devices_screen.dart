import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_bottom_sheet.dart';
import '../providers/devices_provider.dart';

/// Telegram iOS style Devices & Active Sessions screen connected to devicesProvider.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  void _confirmTerminateAll(BuildContext context, WidgetRef ref) async {
    final confirm = await AppBottomSheet.showConfirmation(
      context: context,
      title: 'Terminate All Other Sessions?',
      message: 'Are you sure you want to log out all active sessions on other devices? You will remain logged in on this device.',
      confirmText: 'Terminate All',
      isDestructive: true,
      icon: Icons.phonelink_erase_rounded,
    );

    if (confirm == true) {
      ref.read(devicesProvider.notifier).terminateAllOtherSessions();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All other sessions terminated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(devicesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final curr = state.currentDevice;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Devices & Active Sessions',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (state.suspiciousSessions.isNotEmpty) ...[
            ...state.suspiciousSessions.map((session) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'UNUSUAL IP LOGIN DETECTED',
                            style: TextStyle(
                              color: const Color(0xFFFF3B30),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.suspiciousReason ?? 'A new login occurred from an unrecognized IP address.',
                      style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Device: ${session.deviceName} · IP: ${session.ipAddress} (${session.location})',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => ref.read(devicesProvider.notifier).dismissAlert(session.id),
                            child: const Text('Recognize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B30),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              ref.read(devicesProvider.notifier).terminateSession(session.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Suspicious session terminated & account secured!'),
                                  backgroundColor: Color(0xFFFF3B30),
                                ),
                              );
                            },
                            child: const Text('Terminate & Secure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          // Current Device Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'THIS DEVICE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (curr != null)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: curr.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(curr.icon, color: curr.color, size: 22),
                ),
                title: Text(
                  '${curr.deviceName} (This Device)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${curr.appVersion} · ${curr.location} (${curr.ipAddress})',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ONLINE', style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smartphone_rounded, color: Color(0xFF1877F2), size: 22),
                ),
                title: Text(
                  'Current Device',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Active session',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ONLINE', style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Active Sessions Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'ACTIVE SESSIONS (${state.otherSessions.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (state.otherSessions.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmTerminateAll(context, ref),
                  child: const Text('Terminate All', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),

          if (state.otherSessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'No other active sessions. Your account is only signed in on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.otherSessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                itemBuilder: (ctx, i) {
                  final session = state.otherSessions[i];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: session.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(session.icon, color: session.color, size: 22),
                    ),
                    title: Text(
                      session.deviceName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${session.appVersion} · ${session.location}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.highlight_off_rounded, color: Color(0xFFFF3B30)),
                      onPressed: () {
                        ref.read(devicesProvider.notifier).terminateSession(session.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Session on ${session.deviceName} terminated.')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
