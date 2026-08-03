/// Models for the communities & content domain, parsed from the backend
/// payloads (`author` uses `avatar`, reactions are plain rows, counts are
/// denormalized columns).
library;

import 'chat_models.dart';

class Community {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? category;
  final String visibility;
  final String pricingType;
  final double? priceAmount;
  final String? logoUrl;
  final String? coverUrl;
  final int membersCount;
  final ChatUser? creator;

  const Community({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.category,
    this.visibility = 'public',
    this.pricingType = 'free',
    this.priceAmount,
    this.logoUrl,
    this.coverUrl,
    this.membersCount = 0,
    this.creator,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory Community.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const Community(id: 0, name: '', slug: '');
    }
    return Community(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      pricingType: json['pricing_type'] as String? ?? 'free',
      priceAmount: (json['price_amount'] as num?)?.toDouble(),
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      membersCount:
          (json['members_count'] as num?)?.toInt() ?? (json['active_members_count'] as num?)?.toInt() ?? 0,
      creator: ChatUser.fromJson(json['creator']),
    );
  }
}

/// Membership status for the current user in a community.
class MembershipStatus {
  final bool isMember;
  final bool isPending;
  final String? role;
  final String status;

  const MembershipStatus({
    required this.isMember,
    required this.isPending,
    this.role,
    this.status = 'none',
  });

  factory MembershipStatus.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const MembershipStatus(isMember: false, isPending: false);
    return MembershipStatus(
      isMember: json['is_member'] as bool? ?? false,
      isPending: json['is_pending'] as bool? ?? false,
      role: json['role'] as String?,
      status: json['status'] as String? ?? 'none',
    );
  }
}

/// One community membership row (as listed by `/communities/{id}/members`).
class CommunityMember {
  final int id;
  final int userId;
  final String role;
  final String status;
  final ChatUser? user;

  const CommunityMember({
    required this.id,
    required this.userId,
    this.role = 'member',
    this.status = 'active',
    this.user,
  });

  factory CommunityMember.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CommunityMember(id: 0, userId: 0);
    }
    return CommunityMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'active',
      user: ChatUser.fromJson(json['user']),
    );
  }
}

class PostReaction {
  final int userId;
  final String reactionType;

  const PostReaction({required this.userId, required this.reactionType});

  factory PostReaction.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const PostReaction(userId: 0, reactionType: 'like');
    return PostReaction(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      reactionType: json['reaction_type'] as String? ?? 'like',
    );
  }
}

class Post {
  final int id;
  final int communityId;
  final int userId;
  final String type;
  final String content;
  final List<String> mediaUrls;
  final String? linkUrl;
  final List<String> hashtags;
  final bool isPinned;
  final DateTime? createdAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;
  final ChatUser? author;
  final CommunityRef? community;
  final List<PostReaction> reactions;
  final bool likedByMe;
  final bool savedByMe;

  const Post({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.type,
    required this.content,
    this.mediaUrls = const [],
    this.linkUrl,
    this.hashtags = const [],
    this.isPinned = false,
    this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.author,
    this.community,
    this.reactions = const [],
    this.likedByMe = false,
    this.savedByMe = false,
  });

  bool get hasMedia => mediaUrls.isNotEmpty;
  bool get isPoll => type == 'poll';
  bool get isAnnouncement => type == 'announcement';

  Post copyWith({
    String? content,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? savesCount,
    bool? likedByMe,
    bool? savedByMe,
    bool? isPinned,
  }) {
    return Post(
      id: id,
      communityId: communityId,
      userId: userId,
      type: type,
      content: content ?? this.content,
      mediaUrls: mediaUrls,
      linkUrl: linkUrl,
      hashtags: hashtags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      author: author,
      community: community,
      reactions: reactions,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
    );
  }

  factory Post.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const Post(id: 0, communityId: 0, userId: 0, type: 'post', content: '');
    }
    final rawMedia = json['media_urls'];
    final rawHashtags = json['hashtags'];
    final rawReactions = json['reactions'];
    return Post(
      id: (json['id'] as num?)?.toInt() ?? 0,
      communityId: (json['community_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'post',
      content: json['content'] as String? ?? '',
      mediaUrls: rawMedia is List ? rawMedia.whereType<String>().toList() : const [],
      linkUrl: json['link_url'] as String?,
      hashtags: rawHashtags is List ? rawHashtags.whereType<String>().toList() : const [],
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      savesCount: (json['saves_count'] as num?)?.toInt() ?? 0,
      author: ChatUser.fromJson(json['author']),
      community: CommunityRef.fromJson(json['community']),
      reactions: rawReactions is List ? rawReactions.map(PostReaction.fromJson).toList() : const [],
    );
  }
}

class PostComment {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final DateTime? createdAt;
  final ChatUser? author;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.createdAt,
    this.author,
  });

  factory PostComment.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const PostComment(id: 0, postId: 0, userId: 0, content: '');
    }
    return PostComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['post_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      author: ChatUser.fromJson(json['author']),
    );
  }
}
