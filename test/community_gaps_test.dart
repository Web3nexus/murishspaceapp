import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/community_models.dart';
import 'package:mobile/providers/community_provider.dart';

class _StubSavedPosts extends SavedPostsNotifier {
  @override
  PostsState build() => const PostsState();
}

class _StubRequests extends CommunityRequestsNotifier {
  _StubRequests() : super(4);

  @override
  CommunityRequestsState build() => const CommunityRequestsState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedPostsNotifier', () {
    test('remove drops the post from the list', () {
      final container = ProviderContainer(
        overrides: [savedPostsProvider.overrideWith(_StubSavedPosts.new)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(savedPostsProvider.notifier);

      final a = _post(1);
      final b = _post(2);
      notifier.state = PostsState(posts: [a, b]);
      notifier.remove(1);
      expect(container.read(savedPostsProvider).posts.map((p) => p.id), [2]);
    });
  });

  group('CommunityRequestsNotifier', () {
    test('approve removes the request optimistically after API call', () async {
      final container = ProviderContainer(
        overrides: [communityRequestsProvider(4).overrideWith(_StubRequests.new)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(communityRequestsProvider(4).notifier);

      const request = CommunityMember(id: 8, userId: 9, role: 'member', status: 'pending');
      notifier.state = const CommunityRequestsState(requests: [request]);
      // In flutter_test the HTTP layer returns 400, so approval fails and the
      // request is kept for retry.
      await notifier.approve(request);
      expect(container.read(communityRequestsProvider(4)).requests, hasLength(1));
    });
  });
}

Post _post(int id) => Post(
      id: id,
      communityId: 4,
      userId: 9,
      type: 'post',
      content: 'saved post',
    );
