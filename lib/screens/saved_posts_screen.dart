import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import 'post_card.dart';

/// Saved posts collection — posts you've bookmarked, with quick un-save.
class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedPostsProvider);
    final notifier = ref.read(savedPostsProvider.notifier);
    final myId = ref.watch(authProvider).user?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _body(context, state, myId, notifier),
    );
  }

  Widget _body(BuildContext context, PostsState state, int myId, SavedPostsNotifier notifier) {
    if (state.loading && state.posts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading saved posts…');
    }
    if (state.error != null && state.posts.isEmpty) {
      return ErrorStateWidget(title: 'Could not load saved posts', description: state.error!, onRetry: () => notifier.refresh());
    }
    if (state.posts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bookmark_outline,
        title: 'No saved posts yet',
        description: 'Tap the bookmark on any post to keep it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.posts.length,
        itemBuilder: (_, i) {
          final post = state.posts[i];
          return PostCard(
            post: post,
            myId: myId,
            onSave: () => notifier.unsave(post),
          );
        },
      ),
    );
  }
}
