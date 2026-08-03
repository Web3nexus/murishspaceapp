import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../components/ui_states.dart';

/// Chats tab — conversations list (Phase 1). Empty state for now.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search coming in Phase 1')),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New message coming in Phase 1')),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stories row placeholder (populated in Phase 1).
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: 1,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => const _YourStoryAvatar(),
            ),
          ),
          const Divider(),
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              description: 'Start chatting with friends, communities or businesses.',
            ),
          ),
        ],
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
