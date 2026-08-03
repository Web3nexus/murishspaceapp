import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/format.dart';
import 'new_message_sheet.dart';

/// Chats tab — live conversation list with stories row, saved messages,
/// filters and swipe actions.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _showCommunityPicker(context, ref),
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Start community chat',
          ),
          IconButton(
            onPressed: () => showNewMessageSheet(context),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => showNewMessageSheet(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DesignTokens.primary,
        foregroundColor: Colors.white,
        onPressed: () => showNewMessageSheet(context),
        child: const Icon(Icons.edit_outlined),
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoriesRow(),
          Divider(height: 1),
          _SavedMessagesRow(),
          Divider(height: 1),
          Expanded(child: _ChatBody()),
        ],
      ),
    );
  }

  Future<void> _showCommunityPicker(BuildContext context, WidgetRef ref) async {
    List<CommunityRef> communities = const [];
    try {
      final response = await ApiClient.instance.dio.get('/my-communities');
      final data = response.data;
      final raw = data is Map<String, dynamic> ? data['communities'] : null;
      if (raw is List) {
        communities = raw
            .map(CommunityRef.fromJson)
            .where((c) => c.id != null)
            .toList();
      }
    } catch (_) {
      // Falls through to the empty state.
    }
    if (!context.mounted) return;

    final selected = await showModalBottomSheet<CommunityRef>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => _CommunityPickerSheet(communities: communities),
    );
    if (selected?.id == null || !context.mounted) return;

    final conversation = await ref
        .read(conversationsProvider.notifier)
        .openCommunityChat(selected!.id!);
    if (!context.mounted) return;
    if (conversation != null) {
      context.push('/app/conversation/${conversation.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the community chat.')),
      );
    }
  }
}

class _SavedMessagesRow extends ConsumerWidget {
  const _SavedMessagesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: DesignTokens.primarySoft,
        child: const Icon(Icons.bookmark_outline, color: DesignTokens.primaryDark, size: 20),
      ),
      title: const Text(
        'Saved Messages',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: const Text(
        'Your private notes',
        style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
      ),
      onTap: () async {
        final conversation =
            await ref.read(conversationsProvider.notifier).openSavedMessages();
        if (conversation != null && context.mounted) {
          context.push('/app/conversation/${conversation.id}');
        }
      },
    );
  }
}

class _CommunityPickerSheet extends StatelessWidget {
  final List<CommunityRef> communities;

  const _CommunityPickerSheet({required this.communities});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Start a community chat',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (communities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'You are not a member of any community yet.',
                  style: TextStyle(color: DesignTokens.textSecondary),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: communities.length,
                itemBuilder: (_, i) {
                  final c = communities[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DesignTokens.primarySoft,
                      backgroundImage: c.logoUrl != null && c.logoUrl!.isNotEmpty
                          ? NetworkImage(c.logoUrl!)
                          : null,
                      child: c.logoUrl == null || c.logoUrl!.isEmpty
                          ? Text(
                              c.name == null || c.name!.isEmpty
                                  ? '?'
                                  : c.name!.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: DesignTokens.primaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    title: Text(c.name ?? 'Community'),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody();

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  String _filter = 'All';
  static const _filters = ['All', 'Unread', 'Direct', 'Communities', 'Archived'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final all = state.conversations;
    final archived = all.where((c) => c.isArchived).toList();
    final base = all.where((c) => !c.isArchived).toList();
    final filtered = switch (_filter) {
      'Archived' => archived,
      'Unread' => base.where((c) => c.unreadCount > 0).toList(),
      'Direct' => base.where((c) => c.type == 'direct').toList(),
      'Communities' => base.where((c) => c.type == 'community').toList(),
      _ => base,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = f == _filter;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                backgroundColor: Colors.white,
                selectedColor: DesignTokens.primarySoft,
                side: BorderSide(
                  color: selected ? DesignTokens.primary : DesignTokens.border,
                ),
                labelStyle: TextStyle(
                  color: selected ? DesignTokens.primaryDark : DesignTokens.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _ConversationList(
            state: state,
            filtered: filtered,
            filter: _filter,
            onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }
}

class _ConversationList extends ConsumerWidget {
  final ConversationsState state;
  final List<Conversation> filtered;
  final String filter;
  final Future<void> Function() onRefresh;

  const _ConversationList({
    required this.state,
    required this.filtered,
    required this.filter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.conversations.isEmpty) {
      return const LoadingStateWidget(message: 'Loading conversations…');
    }
    if (state.error != null && state.conversations.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load conversations',
        description: state.error!,
        onRetry: onRefresh,
      );
    }
    if (state.conversations.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        description: 'Start chatting with friends, communities or businesses.',
      );
    }
    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.filter_alt_outlined,
        title: filter == 'Archived' ? 'No archived chats' : 'Nothing matches this filter',
        description: filter == 'Archived'
            ? 'Archive a chat by swiping it to the left.'
            : 'Try another filter to see more conversations.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, i) => _ConversationTile(conversation: filtered[i]),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = conversation.unreadCount;
    final myId = ref.watch(authProvider).user?.id;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _markRead(ref);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _toggleArchive(ref),
      background: _SwipeBackground(
        color: const Color(0xFF2E7D32),
        icon: Icons.done_all,
        label: 'Mark read',
        alignRight: false,
      ),
      secondaryBackground: _SwipeBackground(
        color: conversation.isArchived ? DesignTokens.primary : const Color(0xFFE53935),
        icon: conversation.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        label: conversation.isArchived ? 'Unarchive' : 'Archive',
        alignRight: true,
      ),
      child: InkWell(
        onTap: () => context.push('/app/conversation/${conversation.id}'),
        onLongPress: () => _showTileMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _Avatar(conversation: conversation, unread: unread > 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conversation.isMuted) ...[
                          const Icon(Icons.volume_off_outlined,
                              size: 14, color: DesignTokens.textSecondary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                              color: DesignTokens.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          formatConversationTime(conversation.updatedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0 ? DesignTokens.primaryDark : DesignTokens.textSecondary,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _PreviewLine(conversation: conversation, unread: unread > 0, myId: myId),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignTokens.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markRead(WidgetRef ref) {
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return;
    ref.read(conversationsProvider.notifier).markRead(conversation.id, myId);
  }

  void _toggleArchive(WidgetRef ref) {
    ref
        .read(conversationsProvider.notifier)
        .setSettings(conversation.id, archived: !conversation.isArchived);
  }

  Future<void> _showTileMenu(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(conversationsProvider.notifier);
    final myId = ref.read(authProvider).user?.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            if (conversation.unreadCount > 0)
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Mark as read'),
                onTap: () => Navigator.pop(context, 'read'),
              ),
            ListTile(
              leading: Icon(conversation.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
              title: Text(conversation.isMuted ? 'Unmute notifications' : 'Mute notifications'),
              onTap: () => Navigator.pop(context, 'mute'),
            ),
            ListTile(
              leading: Icon(conversation.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(conversation.isArchived ? 'Unarchive chat' : 'Archive chat'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    switch (action) {
      case 'read':
        if (myId != null) notifier.markRead(conversation.id, myId);
      case 'mute':
        await notifier.setSettings(conversation.id, muted: !conversation.isMuted);
      case 'archive':
        await notifier.setSettings(conversation.id, archived: !conversation.isArchived);
    }
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool alignRight;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Conversation conversation;
  final bool unread;

  const _Avatar({required this.conversation, required this.unread});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: unread ? DesignTokens.primary : DesignTokens.primarySoft,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  conversation.initials,
                  style: TextStyle(
                    color: unread ? Colors.white : DesignTokens.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        if (unread)
          const Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(radius: 5, backgroundColor: DesignTokens.primary),
          ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final Conversation conversation;
  final bool unread;
  final int? myId;

  const _PreviewLine({required this.conversation, required this.unread, this.myId});

  @override
  Widget build(BuildContext context) {
    final message = conversation.latestMessage;
    if (message == null) {
      return Text(
        'No messages yet',
        style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14),
      );
    }
    final preview = messagePreview(message);
    final isMine = message.userId == myId;
    final prefix = isMine
        ? 'You: '
        : (conversation.type == 'community' ? '${message.user?.name ?? ''}: ' : '');
    return Text(
      '$prefix$preview',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: unread ? DesignTokens.textPrimary : DesignTokens.textSecondary,
        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        fontSize: 14,
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => const _YourStoryAvatar(),
      ),
    );
  }
}

class _YourStoryAvatar extends StatelessWidget {
  const _YourStoryAvatar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [DesignTokens.primary, Color(0xFF8B5CF6)],
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.surface,
            ),
            child: const Icon(Icons.add, color: DesignTokens.primaryDark),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your story',
          style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
        ),
      ],
    );
  }
}
