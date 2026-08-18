import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/broadcast_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/format.dart';
import 'new_message_sheet.dart';

/// Chats tab — live conversation list with stories row, saved messages,
/// filters and swipe actions.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF7FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          // Requests Action Button leading to Friends & Community Requests
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: () => context.push('/friends'),
              style: TextButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16, color: Color(0xFF007AFF)),
              label: const Text(
                'Requests',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => showNewMessageSheet(context),
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'New Message',
          ),
        ],
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActiveFriendsRow(),
          Expanded(child: _ChatBody()),
        ],
      ),
    );
  }

  Future<void> showCommunityPicker(BuildContext context, WidgetRef ref) async {
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
                          ? CachedNetworkImageProvider(c.logoUrl!)
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
  bool _showPullHeader = false;
  static const _filters = ['All', 'Communities', 'Marketplace', 'Requests', 'Spam'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(conversationsProvider);
    final all = state.conversations;
    final base = all.where((c) => !c.isArchived).toList();

    final filtered = switch (_filter) {
      'Communities' => base.where((c) => c.type == 'community' || c.community != null).toList(),
      'Marketplace' => base
          .where((c) =>
              c.type == 'marketplace' ||
              c.hasActiveEscrow ||
              c.title.toLowerCase().contains('order') ||
              c.title.toLowerCase().contains('product') ||
              c.title.toLowerCase().contains('store') ||
              c.title.toLowerCase().contains('seller') ||
              c.title.toLowerCase().contains('buyer'))
          .toList(),
      'Spam' => all.where((c) => c.isMuted || c.type == 'spam').toList(),
      _ => base,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta / Instagram Segmented Category Pill Bar with Saved Messages Icon & Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Saved Messages Quick Bookmark Button
                  GestureDetector(
                    onTap: () async {
                      final conversation =
                          await ref.read(conversationsProvider.notifier).openSavedMessages();
                      if (conversation != null && context.mounted) {
                        context.push('/app/conversation/${conversation.id}');
                      }
                    },
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),

                  // Vertical Divider Bar |
                  Container(
                    width: 1.5,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),

                  // Category Filter Pills
                  ..._filters.map((f) {
                    final selected = f == _filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (f == 'Requests') {
                            context.push('/friends');
                          } else {
                            setState(() => _filter = f);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF007AFF)
                                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF3F6)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF007AFF)
                                  : (isDark ? Colors.grey[800]! : Colors.transparent),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (f == 'Communities')
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.groups_rounded,
                                      size: 15, color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                                )
                              else if (f == 'Marketplace')
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.storefront_rounded,
                                      size: 15, color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                                )
                              else if (f == 'Requests')
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.person_add_rounded,
                                      size: 15, color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                                )
                              else if (f == 'Spam')
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.shield_outlined,
                                      size: 15, color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                                ),
                              Text(
                                f,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : (isDark ? Colors.grey[300] : const Color(0xFF1C1E21)),
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        if (_showPullHeader) const _SavedMessagesRow(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              final pixels = scrollInfo.metrics.pixels;
              if (pixels < -30 && !_showPullHeader) {
                setState(() => _showPullHeader = true);
              } else if (pixels > 0 && _showPullHeader) {
                setState(() => _showPullHeader = false);
              }
              return false;
            },
            child: _ConversationList(
              state: state,
              filtered: filtered,
              filter: _filter,
              onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
            ),
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

    // Sort: Pinned chats at the top (sorted by date), followed by unpinned chats (sorted by date)
    final pinned = filtered.where((c) => c.isPinned).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    final unpinned = filtered.where((c) => !c.isPinned).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    final sorted = [...pinned, ...unpinned];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sorted.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return const _SystemBroadcastTile();
        final conversation = sorted[i - 1];
        return Column(
          children: [
            _ConversationTile(conversation: conversation),
            if (i < sorted.length) const Divider(height: 1, indent: 76),
          ],
        );
      },
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
                        if (conversation.isPinned) ...[
                          const Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFF007AFF)),
                          const SizedBox(width: 4),
                        ],
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: const Color(0xFF007AFF),
              ),
              title: Text(
                conversation.isPinned ? 'Unpin chat' : 'Pin chat',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            if (conversation.unreadCount > 0)
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Mark as read'),
                onTap: () => Navigator.pop(ctx, 'read'),
              ),
            ListTile(
              leading: Icon(conversation.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
              title: Text(conversation.isMuted ? 'Unmute notifications' : 'Mute notifications'),
              onTap: () => Navigator.pop(ctx, 'mute'),
            ),
            ListTile(
              leading: Icon(conversation.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(conversation.isArchived ? 'Unarchive chat' : 'Archive chat'),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'pin':
        await _handlePinToggle(context, ref);
      case 'read':
        if (myId != null) notifier.markRead(conversation.id, myId);
      case 'mute':
        await notifier.setSettings(conversation.id, muted: !conversation.isMuted);
      case 'archive':
        await notifier.setSettings(conversation.id, archived: !conversation.isArchived);
    }
  }

  Future<void> _handlePinToggle(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(conversationsProvider.notifier);
    final conversations = ref.read(conversationsProvider).conversations;
    final isVerified = ref.read(authProvider).user?.isVerified ?? false;
    final maxPinLimit = isVerified ? 5 : 3;

    if (!conversation.isPinned) {
      final currentPinnedCount = conversations.where((c) => c.isPinned && !c.isArchived).length;
      if (currentPinnedCount >= maxPinLimit) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.push_pin_rounded, color: Color(0xFF007AFF), size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pin Limit Reached ($currentPinnedCount/$maxPinLimit)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVerified
                        ? 'You have reached the maximum 5 pinned chats limit for Premium members.'
                        : 'Non-Premium users can pin up to 3 chats. Upgrade to MurihSpace Premium to pin up to 5 chats, get your verified star badge, and unlock 4GB file uploads!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (!isVerified) {
                          context.push('/verification-badge');
                        }
                      },
                      child: Text(
                        isVerified ? 'Got it' : 'Upgrade to MurihSpace Premium',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }
    }

    await notifier.setSettings(conversation.id, pinned: !conversation.isPinned);
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
              ? CachedNetworkImageProvider(avatarUrl)
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

class _ActiveFriendsRow extends ConsumerWidget {
  const _ActiveFriendsRow();

  static const List<Map<String, dynamic>> _fallbackActiveFriends = [
    {
      'id': 101,
      'name': 'Houns S.',
      'username': 'houns_s',
      'avatarUrl': 'https://picsum.photos/seed/houns/150/150',
      'color': 0xFF007AFF,
      'isOnline': true,
    },
    {
      'id': 102,
      'name': 'Alex Vance',
      'username': 'alex_v',
      'avatarUrl': 'https://picsum.photos/seed/alex/150/150',
      'color': 0xFF34C759,
      'isOnline': true,
    },
    {
      'id': 103,
      'name': 'Sarah C.',
      'username': 'sarah_c',
      'avatarUrl': 'https://picsum.photos/seed/sarah/150/150',
      'color': 0xFFAF52DE,
      'isOnline': true,
    },
    {
      'id': 104,
      'name': 'DevPulse Hub',
      'username': 'devpulse',
      'avatarUrl': 'https://picsum.photos/seed/devpulse/150/150',
      'color': 0xFFFF9500,
      'isOnline': true,
      'isCommunity': true,
      'communityId': 10,
    },
    {
      'id': 105,
      'name': 'Elena R.',
      'username': 'elena_r',
      'avatarUrl': 'https://picsum.photos/seed/elena/150/150',
      'color': 0xFFFF2D55,
      'isOnline': true,
    },
    {
      'id': 106,
      'name': 'Marcus',
      'username': 'marcus_t',
      'avatarUrl': 'https://picsum.photos/seed/marcus/150/150',
      'color': 0xFF5856D6,
      'isOnline': false,
    },
  ];

  Future<void> _openChatForFriend(
    BuildContext context,
    WidgetRef ref, {
    required int friendId,
    required String name,
    required String username,
    String? avatarUrl,
    bool isCommunity = false,
    int? communityId,
  }) async {
    if (isCommunity && communityId != null) {
      final conv = await ref
          .read(conversationsProvider.notifier)
          .openCommunityChat(communityId);
      if (context.mounted && conv != null) {
        context.push('/app/conversation/${conv.id}');
      }
      return;
    }

    final conv = await ref
        .read(conversationsProvider.notifier)
        .openDirectChat(
          friendId,
          name: name,
          username: username,
          avatarUrl: avatarUrl,
        );

    if (context.mounted && conv != null) {
      context.push('/app/conversation/${conv.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conversationsState = ref.watch(conversationsProvider);

    // Derive active friends from ongoing conversations + fallback list
    final List<Map<String, dynamic>> activeList = [];

    for (final conv in conversationsState.conversations) {
      if (conv.type == 'direct' && conv.otherUser != null) {
        final u = conv.otherUser!;
        activeList.add({
          'id': u.id,
          'name': u.name.isNotEmpty ? u.name : 'Friend',
          'username': u.username,
          'avatarUrl': u.avatarUrl,
          'color': 0xFF007AFF,
          'isOnline': true,
          'conversationId': conv.id,
        });
      } else if (conv.type == 'community' && conv.community != null) {
        final c = conv.community!;
        if (c.id != null) {
          activeList.add({
            'id': c.id!,
            'name': c.name ?? 'Community',
            'username': c.slug ?? 'community',
            'avatarUrl': c.logoUrl,
            'color': 0xFF5856D6,
            'isOnline': true,
            'isCommunity': true,
            'communityId': c.id,
            'conversationId': conv.id,
          });
        }
      }
    }

    // Append fallback list items if active list is small
    for (final fallback in _fallbackActiveFriends) {
      final fId = fallback['id'] as int;
      if (!activeList.any((item) => item['id'] == fId)) {
        activeList.add(fallback);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 4),
          child: Text(
            'ACTIVE FRIENDS & SPACES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: activeList.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final friend = activeList[index];
              final friendId = friend['id'] as int;
              final name = friend['name'] as String;
              final username = friend['username'] as String? ?? 'user_$friendId';
              final avatarUrl = friend['avatarUrl'] as String?;
              final isOnline = friend['isOnline'] as bool? ?? true;
              final isCommunity = friend['isCommunity'] as bool? ?? false;
              final communityId = friend['communityId'] as int?;
              final conversationId = friend['conversationId'] as int?;
              final colorInt = friend['color'] as int? ?? 0xFF007AFF;
              final color = Color(colorInt);

              return GestureDetector(
                onTap: () {
                  if (conversationId != null) {
                    context.push('/app/conversation/$conversationId');
                  } else {
                    _openChatForFriend(
                      context,
                      ref,
                      friendId: friendId,
                      name: name,
                      username: username,
                      avatarUrl: avatarUrl,
                      isCommunity: isCommunity,
                      communityId: communityId,
                    );
                  }
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: color.withOpacity(0.18),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isCommunity ? const Color(0xFF5856D6) : const Color(0xFF34C759),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.black : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 58,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SystemBroadcastTile extends ConsumerWidget {
  const _SystemBroadcastTile();

  void _showBroadcastSheet(BuildContext context, WidgetRef ref) {
    ref.read(broadcastProvider.notifier).markAllAsRead();

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
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        return Consumer(
          builder: (context, ref, _) {
            final bState = ref.watch(broadcastProvider);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.70,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF007AFF), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'MurihSpace Official Broadcast',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 16),
                                ],
                              ),
                              Text('Platform updates, security alerts & OTP receipts', style: TextStyle(fontSize: 12, color: textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: bState.messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final msg = bState.messages[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: msg.color.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(msg.icon, color: msg.color, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        msg.title,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                                      ),
                                    ),
                                    Text(
                                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 11, color: textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  msg.body,
                                  style: TextStyle(fontSize: 13, color: textPrimary, height: 1.35),
                                ),
                                if (msg.otpCode != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.key_rounded, color: Color(0xFFFF9500), size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'SMS OTP CODE: ${msg.otpCode}',
                                          style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (msg.actionUrl != null) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: msg.color,
                                      side: BorderSide(color: msg.color),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      context.push(msg.actionUrl!);
                                    },
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                    label: const Text('Review Security Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final bState = ref.watch(broadcastProvider);

    return InkWell(
      onTap: () => _showBroadcastSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.12 : 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '📢 MurihSpace System',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textPrimary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 15),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('OFFICIAL', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bState.messages.isNotEmpty ? bState.messages.first.title : 'Official System Broadcasts & Security Alerts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: bState.unreadCount > 0 ? const Color(0xFF007AFF) : textSecondary, fontWeight: bState.unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
            if (bState.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${bState.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
