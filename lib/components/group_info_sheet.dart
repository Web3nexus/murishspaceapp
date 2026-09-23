import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../models/group_models.dart';
import '../providers/chat_provider.dart';
import '../providers/groups_provider.dart';

/// Bottom sheet that shows group details with Join/Leave and Open Chat actions.
class GroupInfoSheet extends ConsumerStatefulWidget {
  final Group group;

  const GroupInfoSheet({super.key, required this.group});

  static void show(BuildContext context, Group group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GroupInfoSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<GroupInfoSheet> {
  bool _joining = false;
  bool _leaving = false;
  bool _openingChat = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF61758A);
    final group = widget.group;
    final isMember = group.isMember;
    final isOwner = group.isOwner;
    final pending = group.hasPendingRequest;
    final avatarUrl = group.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: DesignTokens.primarySoft,
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.groups_rounded, color: DesignTokens.primary, size: 30)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded,
                            size: 14, color: isDark ? Colors.grey[400] : const Color(0xFF61758A)),
                        const SizedBox(width: 4),
                        Text(
                          '${group.membersCount} members',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                        if (group.category != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignTokens.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${group.category} · ${_privacyLabel(group.privacy)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFFFF9500)),
                      SizedBox(width: 3),
                      Text(
                        'Owner',
                        style: TextStyle(
                          color: Color(0xFFFF9500),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (group.description != null && group.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              group.description!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: isMember
                      ? OutlinedButton(
                          onPressed: _leaving ? null : () => _leaveGroup(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6)),
                            foregroundColor: const Color(0xFFFF3B30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _leaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Leave'),
                        )
                      : FilledButton(
                          onPressed: (_joining || pending) ? null : () => _joinGroup(),
                          style: FilledButton.styleFrom(
                            backgroundColor: pending ? Colors.grey : DesignTokens.primary,
                            disabledBackgroundColor:
                                isDark ? Colors.grey[700] : Colors.grey[300],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _joining
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(pending ? 'Request Pending' : 'Join Group'),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.tonal(
                    onPressed: _openingChat ? null : () => _openChat(),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primarySoft,
                      foregroundColor: DesignTokens.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _openingChat
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, size: 17),
                              SizedBox(width: 6),
                              Text('Chat',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
  }

  String _privacyLabel(String privacy) {
    switch (privacy) {
      case 'private':
        return 'Private';
      case 'invite_only':
        return 'Invite only';
      default:
        return 'Public';
    }
  }

  Future<void> _joinGroup() async {
    setState(() => _joining = true);
    final result = await ref.read(discoverGroupsProvider.notifier).joinGroup(widget.group.id);
    if (!mounted) return;
    setState(() => _joining = false);
    if (result is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join this group. Please try again.')),
      );
      return;
    }
    Navigator.pop(context);
    final status = result['status']?.toString() ?? 'joined';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == 'pending_approval'
            ? 'Join request submitted to the group admin.'
            : 'Joined ${widget.group.name}!'),
      ),
    );
    ref.read(myGroupsProvider.notifier).refresh();
  }

  Future<void> _leaveGroup() async {
    setState(() => _leaving = true);
    final left = await ref.read(discoverGroupsProvider.notifier).leaveGroup(widget.group.id);
    if (!mounted) return;
    setState(() => _leaving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(left ? 'You left the group.' : 'Could not leave this group. Please try again.'),
      ),
    );
    if (left) ref.read(myGroupsProvider.notifier).refresh();
  }

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    final conversation =
        await ref.read(conversationsProvider.notifier).openGroupChat(widget.group.id);
    if (!mounted) return;
    Navigator.pop(context);
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the group chat.')),
      );
      return;
    }
    context.push('/app/conversation/${conversation.id}');
  }
}