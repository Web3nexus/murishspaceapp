import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/community_models.dart';

void main() {
  group('Community', () {
    test('parses list payload with creator', () {
      final community = Community.fromJson({
        'id': 4,
        'name': 'Murih Society',
        'slug': 'murih-society',
        'description': 'A community for the region.',
        'category': 'regional',
        'visibility': 'public',
        'pricing_type': 'free',
        'logo_url': 'http://x/logo.png',
        'members_count': 42,
        'creator': {'id': 1, 'name': 'Vincent', 'username': 'vincent', 'avatar': 'http://x/a.png'},
      });
      expect(community.id, 4);
      expect(community.name, 'Murih Society');
      expect(community.slug, 'murih-society');
      expect(community.membersCount, 42);
      expect(community.logoUrl, 'http://x/logo.png');
      expect(community.creator?.name, 'Vincent');
      expect(community.creator?.avatarUrl, 'http://x/a.png');
    });

    test('uses active_members_count when members_count absent', () {
      final community = Community.fromJson({
        'id': 5,
        'name': 'X',
        'slug': 'x',
        'active_members_count': 7,
      });
      expect(community.membersCount, 7);
    });

    test('initials from name', () {
      expect(Community(id: 1, name: 'John Doe', slug: 'jd').initials, 'JD');
      expect(Community(id: 2, name: 'Alice', slug: 'a').initials, 'A');
    });
  });

  group('MembershipStatus', () {
    test('parses membership states', () {
      expect(MembershipStatus.fromJson({'is_member': true, 'role': 'member'}).isMember, true);
      expect(MembershipStatus.fromJson({'is_pending': true}).isPending, true);
      expect(MembershipStatus.fromJson({'status': 'none'}).status, 'none');
    });
  });

  group('Post', () {
    test('parses feed payload with media, hashtags and reactions', () {
      final post = Post.fromJson({
        'id': 10,
        'community_id': 4,
        'user_id': 3,
        'type': 'post',
        'content': 'Hello community',
        'media_urls': ['http://x/1.png', 'http://x/2.png'],
        'hashtags': ['#welcome', '#murih'],
        'is_pinned': true,
        'likes_count': 5,
        'comments_count': 2,
        'shares_count': 1,
        'saves_count': 0,
        'created_at': '2026-08-03T12:00:00Z',
        'author': {'id': 3, 'name': 'Ann', 'username': 'ann', 'avatar': 'http://x/a.png'},
        'community': {'id': 4, 'name': 'Murih Society', 'slug': 'murih-society'},
        'reactions': [
          {'id': 1, 'post_id': 10, 'user_id': 9, 'reaction_type': 'like'},
        ],
      });
      expect(post.id, 10);
      expect(post.content, 'Hello community');
      expect(post.mediaUrls, hasLength(2));
      expect(post.hashtags, ['#welcome', '#murih']);
      expect(post.isPinned, true);
      expect(post.likesCount, 5);
      expect(post.commentsCount, 2);
      expect(post.author?.name, 'Ann');
      expect(post.community?.name, 'Murih Society');
      expect(post.reactions.single.userId, 9);
    });

    test('copyWith toggles engagement state', () {
      const post = Post(id: 1, communityId: 4, userId: 3, type: 'post', content: 'x', likesCount: 3, savedByMe: false);
      final liked = post.copyWith(likedByMe: true, likesCount: 4);
      expect(liked.likedByMe, true);
      expect(liked.likesCount, 4);
      expect(liked.savedByMe, false);
    });
  });

  group('CommunityMember', () {
    test('parses membership with nested user', () {
      final member = CommunityMember.fromJson({
        'id': 8,
        'community_id': 4,
        'user_id': 9,
        'role': 'moderator',
        'status': 'active',
        'user': {'id': 9, 'name': 'Ann', 'username': 'ann'},
      });
      expect(member.userId, 9);
      expect(member.role, 'moderator');
      expect(member.user?.name, 'Ann');
    });
  });

  group('PostComment', () {
    test('parses comment payload', () {
      final comment = PostComment.fromJson({
        'id': 3,
        'post_id': 10,
        'user_id': 9,
        'content': 'Nice post!',
        'author': {'id': 9, 'name': 'Ann', 'username': 'ann'},
      });
      expect(comment.postId, 10);
      expect(comment.content, 'Nice post!');
      expect(comment.author?.name, 'Ann');
    });
  });
}
