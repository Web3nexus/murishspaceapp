/// Data models for 24-hour disappearing Stories (Status Updates).

class StoryItem {
  final String id;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewsCount;
  final bool isSeen;
  final String mediaType; // 'image' or 'video'

  const StoryItem({
    required this.id,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewsCount = 0,
    this.isSeen = false,
    this.mediaType = 'image',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  StoryItem copyWith({
    String? id,
    String? mediaUrl,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewsCount,
    bool? isSeen,
    String? mediaType,
  }) {
    return StoryItem(
      id: id ?? this.id,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewsCount: viewsCount ?? this.viewsCount,
      isSeen: isSeen ?? this.isSeen,
      mediaType: mediaType ?? this.mediaType,
    );
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now();
    final expires = json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : created.add(const Duration(hours: 24));

    return StoryItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      mediaUrl: json['media_url'] as String? ?? 'https://picsum.photos/seed/story/600/1000',
      caption: json['caption'] as String?,
      createdAt: created,
      expiresAt: expires,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      isSeen: json['is_seen'] as bool? ?? false,
      mediaType: json['media_type'] as String? ?? 'image',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'media_url': mediaUrl,
        'caption': caption,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'views_count': viewsCount,
        'is_seen': isSeen,
        'media_type': mediaType,
      };
}

class UserStoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isMyStory;
  final bool isCommunity;
  final String? communityName;
  final List<StoryItem> stories;

  const UserStoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isMyStory = false,
    this.isCommunity = false,
    this.communityName,
    required this.stories,
  });

  bool get hasUnseen => stories.any((s) => !s.isSeen && !s.isExpired);

  UserStoryGroup copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isMyStory,
    bool? isCommunity,
    String? communityName,
    List<StoryItem>? stories,
  }) {
    return UserStoryGroup(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isMyStory: isMyStory ?? this.isMyStory,
      isCommunity: isCommunity ?? this.isCommunity,
      communityName: communityName ?? this.communityName,
      stories: stories ?? this.stories,
    );
  }

  factory UserStoryGroup.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'] as List<dynamic>? ?? [];
    return UserStoryGroup(
      userId: json['user_id']?.toString() ?? '0',
      userName: json['user_name'] as String? ?? 'Friend',
      userAvatar: json['user_avatar'] as String?,
      isMyStory: json['is_my_story'] as bool? ?? false,
      isCommunity: json['is_community'] as bool? ?? false,
      communityName: json['community_name'] as String?,
      stories: rawStories.map((s) => StoryItem.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
