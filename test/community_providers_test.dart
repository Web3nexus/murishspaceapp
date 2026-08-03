import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/community_models.dart';
import 'package:mobile/providers/community_provider.dart';

class _StubMyCommunities extends MyCommunitiesNotifier {
  @override
  CommunitiesState build() => const CommunitiesState();
}

class _StubPosts extends PostsNotifier {
  _StubPosts() : super(const PostsSource.feed('home'));

  @override
  PostsState build() => const PostsState();
}

Post _post({int id = 1, bool likedByMe = false, int likesCount = 0}) => Post(
      id: id,
      communityId: 4,
      userId: 9,
      type: 'post',
      content: 'hello',
      likesCount: likesCount,
      reactions: const [PostReaction(userId: 9, reactionType: 'like')],
      likedByMe: likedByMe,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyCommunitiesNotifier', () {
    test('upsert prepends and dedupes by id', () {
      final container = ProviderContainer(
        overrides: [myCommunitiesProvider.overrideWith(_StubMyCommunities.new)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(myCommunitiesProvider.notifier);

      const a = Community(id: 1, name: 'A', slug: 'a');
      const b = Community(id: 2, name: 'B', slug: 'b');
      notifier.upsert(a);
      notifier.upsert(b);
      notifier.upsert(a);
      expect(container.read(myCommunitiesProvider).communities.map((c) => c.id), [1, 2]);
    });

    test('remove drops the community', () {
      final container = ProviderContainer(
        overrides: [myCommunitiesProvider.overrideWith(_StubMyCommunities.new)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(myCommunitiesProvider.notifier);

      const a = Community(id: 1, name: 'A', slug: 'a');
      const b = Community(id: 2, name: 'B', slug: 'b');
      notifier.upsert(a);
      notifier.upsert(b);
      notifier.remove(1);
      expect(container.read(myCommunitiesProvider).communities.map((c) => c.id), [2]);
    });
  });

  group('PostsNotifier', () {
    test('prepend inserts at the front', () {
      final container = ProviderContainer(
        overrides: [
          postsProvider(const PostsSource.feed('home')).overrideWith(_StubPosts.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(postsProvider(const PostsSource.feed('home')).notifier);

      notifier.prepend(_post(id: 1));
      notifier.prepend(_post(id: 2));
      final ids = container.read(postsProvider(const PostsSource.feed('home'))).posts.map((p) => p.id);
      expect(ids, [2, 1]);
    });

    test('hydrateMyReactions marks likedByMe from reaction rows', () {
      final container = ProviderContainer(
        overrides: [
          postsProvider(const PostsSource.feed('home')).overrideWith(_StubPosts.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(postsProvider(const PostsSource.feed('home')).notifier);

      notifier.prepend(_post());
      notifier.hydrateMyReactions(9);
      final post = container.read(postsProvider(const PostsSource.feed('home'))).posts.single;
      expect(post.likedByMe, true);
    });

    test('toggleLike rolls back to the original state when the API call fails', () async {
      final container = ProviderContainer(
        overrides: [
          postsProvider(const PostsSource.feed('home')).overrideWith(_StubPosts.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(postsProvider(const PostsSource.feed('home')).notifier);

      final original = _post(likedByMe: false, likesCount: 3);
      notifier.prepend(original);
      // In flutter_test the HTTP layer returns 400, so the POST fails and the
      // optimistic update is reverted.
      await notifier.toggleLike(original, myId: 9);
      final post = container.read(postsProvider(const PostsSource.feed('home'))).posts.single;
      expect(post.likedByMe, false);
      expect(post.likesCount, 3);
    });
  });
}
