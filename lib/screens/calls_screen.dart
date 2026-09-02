import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/calls_provider.dart';
import '../providers/friends_provider.dart';
import 'call_screen.dart';

/// Interactive Calls Screen with Friend Picker & Modern Call Modal.
class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  void _showStartCallFriendPicker(BuildContext context, WidgetRef ref) {
    final friendsState = ref.read(friendsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final friends = friendsState.friends;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start a Call',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Select a friend or contact to call',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: friends.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 48, color: textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No Friends Found',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add friends on MurihSpace to start voice and HD video calls.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.push('/friends');
                                  },
                                  child: const Text('Discover Friends'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: friends.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                            itemBuilder: (context, idx) {
                              final friend = friends[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                                      backgroundImage: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                                          ? CachedNetworkImageProvider(friend.avatarUrl!)
                                          : null,
                                      child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                                          ? Text(
                                              friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                                            )
                                          : null,
                                    ),
                                    if (friend.isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: bg, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  friend.name,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                                ),
                                subtitle: Text(
                                  '@${friend.username}',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8E8E93)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showCallOptionsModal(context, friend);
                                },
                              );
                            },
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

  void _showCallOptionsModal(BuildContext context, FriendUserItem friend) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                backgroundImage: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(friend.avatarUrl!)
                    : null,
                child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                    ? Text(
                        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF007AFF)),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                friend.name,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textPrimary),
              ),
              Text(
                '@${friend.username}',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),

              // Modern Call Options
              Row(
                children: [
                  // Voice Call Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              contactName: friend.name,
                              phoneNumber: '@${friend.username}',
                              avatarUrl: friend.avatarUrl,
                              isVideo: false,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF34C759).withOpacity(0.4)),
                        ),
                        child: const Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF34C759),
                              child: Icon(Icons.call_rounded, color: Colors.white, size: 22),
                            ),
                            SizedBox(height: 8),
                            Text('Voice Call', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF34C759))),
                            Text('Clear Audio', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // HD Video Call Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              contactName: friend.name,
                              phoneNumber: '@${friend.username}',
                              avatarUrl: friend.avatarUrl,
                              isVideo: true,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.4)),
                        ),
                        child: const Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF007AFF),
                              child: Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                            ),
                            SizedBox(height: 8),
                            Text('HD Video', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF007AFF))),
                            Text('Face to Face', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            onPressed: () => _showStartCallFriendPicker(context, ref),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_call, color: Color(0xFF007AFF), size: 18),
            ),
            tooltip: 'Start Call',
          ),
          if (state.calls.isNotEmpty)
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
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, size: 48, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 16),
                  Text('No Call Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    'Your recent audio and HD video calls will appear here.\nTap Start Call to reach a friend.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _showStartCallFriendPicker(context, ref),
                    icon: const Icon(Icons.add_call, size: 18),
                    label: const Text('Start a Call', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.filteredCalls.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 64,
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                ),
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
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: call.color.withOpacity(0.15),
                        backgroundImage: call.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(call.avatarUrl)
                            : null,
                        child: call.avatarUrl.isEmpty
                            ? Icon(call.icon, color: call.color, size: 18)
                            : null,
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
                        icon: Icon(
                          call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          color: const Color(0xFF34C759),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CallScreen(
                                contactName: call.contactName,
                                phoneNumber: call.phoneNumber,
                                avatarUrl: call.avatarUrl,
                                isVideo: call.isVideo,
                              ),
                            ),
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
}
