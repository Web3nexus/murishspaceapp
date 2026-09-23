/// Models for the Groups domain (backed by `/groups*` API endpoints).
library;

import 'chat_models.dart';

class Group {
  final int id;
  final int? creatorId;
  final String name;
  final String slug;
  final String? description;
  final String? avatarUrl;
  final String? coverUrl;
  final String? category;
  final String privacy;
  final String discoverability;
  final int membersCount;
  final int postsCount;
  final bool isMember;
  final bool hasPendingRequest;
  final String? userRole;
  final ChatUser? creator;

  bool get isOwner => userRole == 'owner';

  const Group({
    required this.id,
    this.creatorId,
    required this.name,
    required this.slug,
    this.description,
    this.avatarUrl,
    this.coverUrl,
    this.category,
    this.privacy = 'public',
    this.discoverability = 'discoverable',
    this.membersCount = 0,
    this.postsCount = 0,
    this.isMember = false,
    this.hasPendingRequest = false,
    this.userRole,
    this.creator,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory Group.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const Group(id: 0, name: '', slug: '');
    }
    final creatorUser = ChatUser.fromJson(json['creator']);
    return Group(
      id: (json['id'] as num?)?.toInt() ?? 0,
      creatorId: (json['creator_id'] as num?)?.toInt() ??
          (creatorUser.id != 0 ? creatorUser.id : null),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      category: json['category']?.toString(),
      privacy: json['privacy']?.toString() ?? 'public',
      discoverability: json['discoverability']?.toString() ?? 'discoverable',
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
      isMember: (json['is_member'] as bool?) ?? false,
      hasPendingRequest: (json['has_pending_request'] as bool?) ?? false,
      userRole: json['user_role']?.toString(),
      creator: creatorUser,
    );
  }
}