import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/format.dart';
import 'new_message_sheet.dart';

/// Chats tab — live conversation list with stories row and filters.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
          Expanded(child: _ChatBody()),
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
  static const _filters = ['All', 'Unread', 'Direct', 'Communities'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final all = state.conversations;
    final filtered = switch (_filter) {
      'Unread' => all.where((c) => c.unreadCount > 0).toList(),
      'Direct' => all.where((c) => c.type == 'direct').toList(),
      'Communities' => all.where((c) => c.type == 'community').toList(),
      _ => all,
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
  final Future<void> Function() onRefresh;

  const _ConversationList({
    required this.state,
    required this.filtered,
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
      return const EmptyStateWidget(
        icon: Icons.filter_alt_outlined,
        title: 'Nothing matches this filter',
        description: 'Try another filter to see more conversations.',
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

    return InkWell(
      onTap: () => context.push('/app/conversation/${conversation.id}'),
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
