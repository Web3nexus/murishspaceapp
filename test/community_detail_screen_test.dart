import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';
import 'package:mobile/models/chat_models.dart';
import 'package:mobile/models/community_models.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/community_provider.dart';
import 'package:mobile/screens/community_detail_screen.dart';

class _AuthNotifier extends AuthNotifier {
  final UserProfile profile;

  _AuthNotifier(this.profile);

  @override
  AuthState build() {
    return AuthState(user: profile, token: 'test-token');
  }
}

final _signedInUser = UserProfile(
  id: 5,
  name: 'Me',
  email: 'me@example.com',
  username: 'me',
  role: UserRole.member,
  kycStatus: 'pending',
  emailVerified: true,
);

class _StubDetail extends CommunityDetailNotifier {
  _StubDetail() : super('murih');

  @override
  CommunityDetailState build() {
    return const CommunityDetailState(
      loading: false,
      community: Community(
        id: 4,
        name: 'Murih Society',
        slug: 'murih',
        description: 'A community for the region.',
        membersCount: 42,
      ),
      membership: MembershipStatus(isMember: true, isPending: false, role: 'member', status: 'active'),
    );
  }
}

class _StubPosts extends PostsNotifier {
  _StubPosts() : super(const PostsSource.community(4));

  @override
  PostsState build() {
    return const PostsState(
      loading: false,
      posts: [
        Post(
          id: 1,
          communityId: 4,
          userId: 9,
          type: 'post',
          content: 'A community post',
          author: ChatUser(id: 9, name: 'Ann', username: 'ann'),
        ),
      ],
    );
  }
}

class _StubMembers extends CommunityMembersNotifier {
  _StubMembers() : super(4);

  @override
  CommunityMembersState build() {
    return const CommunityMembersState(
      loading: false,
      members: [
        CommunityMember(
          id: 1,
          userId: 9,
          role: 'member',
          status: 'active',
          user: ChatUser(id: 9, name: 'Ann', username: 'ann'),
        ),
      ],
    );
  }
}

void main() {
  Widget build() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _AuthNotifier(_signedInUser)),
        communityDetailProvider('murih').overrideWith(_StubDetail.new),
        postsProvider(const PostsSource.community(4)).overrideWith(_StubPosts.new),
        communityMembersProvider(4).overrideWith(_StubMembers.new),
      ],
      child: const MaterialApp(home: CommunityDetailScreen(slug: 'murih')),
    );
  }

  testWidgets('renders community header, membership and feed posts', (tester) async {
    await tester.pumpWidget(build());
    await tester.pump();

    expect(find.text('Murih Society'), findsWidgets);
    expect(find.text('42 members'), findsOneWidget);
    expect(find.text('A community post'), findsOneWidget);
    // Member state shows the Leave button instead of Join.
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Join community'), findsNothing);
  });

  testWidgets('shows pending state when join request is waiting', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _AuthNotifier(_signedInUser)),
        communityDetailProvider('murih').overrideWith(_PendingDetail.new),
        postsProvider(const PostsSource.community(4)).overrideWith(_StubPosts.new),
        communityMembersProvider(4).overrideWith(_StubMembers.new),
      ],
      child: const MaterialApp(home: CommunityDetailScreen(slug: 'murih')),
    ));
    await tester.pump();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Join community'), findsNothing);
  });
}

class _PendingDetail extends CommunityDetailNotifier {
  _PendingDetail() : super('murih');

  @override
  CommunityDetailState build() {
    return const CommunityDetailState(
      loading: false,
      community: Community(id: 4, name: 'Murih Society', slug: 'murih', membersCount: 7),
      membership: MembershipStatus(isMember: false, isPending: true, status: 'pending'),
    );
  }
}
