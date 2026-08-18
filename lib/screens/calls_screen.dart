import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../components/send_gift_dialog.dart';
import '../providers/calls_provider.dart';

/// Telegram iOS style Recent Calls screen connected to callsProvider.
class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  void _showNewCallDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isVideo = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Start New Call', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_rounded),
                      labelText: 'Contact Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_rounded),
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text('Video Call', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                    value: isVideo,
                    onChanged: (v) => setModalState(() => isVideo = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty) return;

                        ref.read(callsProvider.notifier).logNewCall(
                              contactName: name,
                              phoneNumber: phone.isEmpty ? '+1 555 0192' : phone,
                              direction: CallDirection.outgoing,
                              durationSeconds: 180,
                              isVideo: isVideo,
                            );

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Call connected with $name! Logged to call history.')),
                        );
                      },
                      icon: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
                      label: const Text('Start Call', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Recent Calls',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showNewCallDialog(context, ref),
            icon: const Icon(Icons.add_call, color: Color(0xFF007AFF)),
            tooltip: 'Start Call',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            onSelected: (val) {
              if (val == 'clear') {
                ref.read(callsProvider.notifier).clearCallLog();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Call log cleared')),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Call History')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 3 Communication Formats Quick Access
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  context,
                  title: 'Conference',
                  subtitle: 'Group Room',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF007AFF),
                  onTap: () => context.push('/app/conference'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeCard(
                  context,
                  title: 'Live Stage',
                  subtitle: 'Broadcast & Gifts',
                  icon: Icons.live_tv_rounded,
                  color: const Color(0xFFFF9500),
                  onTap: () => context.push('/app/live'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Chips (All vs Missed)
          Row(
            children: [
              ChoiceChip(
                label: const Text('All Calls', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: state.filter == 'all',
                onSelected: (_) => ref.read(callsProvider.notifier).setFilter('all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Missed Calls', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: state.filter == 'missed',
                onSelected: (_) => ref.read(callsProvider.notifier).setFilter('missed'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (state.filteredCalls.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.phone_missed_rounded, size: 54, color: textSecondary),
                  const SizedBox(height: 10),
                  Text('No Call Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text('Your recent audio & video calls will appear here.', style: TextStyle(color: textSecondary, fontSize: 13)),
                ],
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
                itemCount: state.filteredCalls.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                itemBuilder: (ctx, i) {
                  final call = state.filteredCalls[i];
                  return Dismissible(
                    key: Key(call.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: const Color(0xFFFF3B30),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref.read(callsProvider.notifier).deleteCall(call.id);
                    },
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: call.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(call.icon, color: call.color, size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              call.contactName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (call.isVideo)
                            const Icon(Icons.videocam_rounded, size: 16, color: Color(0xFF007AFF)),
                        ],
                      ),
                      subtitle: Text(
                        '${call.formattedType} · ${call.phoneNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.call_rounded, color: Color(0xFF34C759)),
                        onPressed: () {
                          ref.read(callsProvider.notifier).logNewCall(
                                contactName: call.contactName,
                                phoneNumber: call.phoneNumber,
                                direction: CallDirection.outgoing,
                                durationSeconds: 60,
                                isVideo: call.isVideo,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling ${call.contactName}…')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
