/// Models for the messaging domain, parsed from the backend envelope payloads.
///
/// Field names match the Laravel serialization (`user`, `latest_message`,
/// `unread_count`, ...) so the app can round-trip without renames.
library;

class ChatUser {
  final int id;
  final String name;
  final String username;
  final String? avatarUrl;

  const ChatUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory ChatUser.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const ChatUser(id: 0, name: '', username: '');
    return ChatUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: (json['avatar_url'] ?? json['avatar']) as String?,
    );
  }
}

class CommunityRef {
  final int? id;
  final String? name;
  final String? slug;
  final String? logoUrl;

  const CommunityRef({this.id, this.name, this.slug, this.logoUrl});

  factory CommunityRef.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const CommunityRef();
    return CommunityRef(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class ReactionSummary {
  final String emoji;
  final int count;
  final bool byMe;
  final List<int> users;

  const ReactionSummary({
    required this.emoji,
    required this.count,
    required this.byMe,
    this.users = const [],
  });

  factory ReactionSummary.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const ReactionSummary(emoji: '', count: 0, byMe: false);
    }
    final rawUsers = json['users'];
    return ReactionSummary(
      emoji: json['emoji'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      byMe: json['by_me'] as bool? ?? false,
      users: rawUsers is List
          ? rawUsers.whereType<num>().map((e) => e.toInt()).toList()
          : const [],
    );
  }
}

class Message {
  final int id;
  final int conversationId;
  final int userId;
  final String content;
  final String type;
  final String status;
  final String? clientUuid;
  final int? replyToId;
  final Message? replyTo;
  final int? forwardedFromMessageId;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? mediaStatus;
  final DateTime? createdAt;
  final ChatUser? user;
  final List<ReactionSummary> reactions;
  final bool deleted;
  final bool read;

  const Message({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    required this.type,
    required this.status,
    this.clientUuid,
    this.replyToId,
    this.replyTo,
    this.forwardedFromMessageId,
    this.attachmentUrl,
    this.attachmentType,
    this.mediaStatus,
    this.createdAt,
    this.user,
    this.reactions = const [],
    this.deleted = false,
    this.read = false,
  });

  bool get hasAttachment =>
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) || (mediaStatus != null && mediaStatus != 'ready');

  bool get isVoice => attachmentType == 'voice' || type == 'voice';
  bool get isImage => attachmentType == 'image' || type == 'image';

  Message copyWith({
    String? status,
    String? content,
    List<ReactionSummary>? reactions,
    bool? deleted,
    bool? read,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      userId: userId,
      content: content ?? this.content,
      type: type,
      status: status ?? this.status,
      clientUuid: clientUuid,
      replyToId: replyToId,
      replyTo: replyTo,
      forwardedFromMessageId: forwardedFromMessageId,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      mediaStatus: mediaStatus,
      createdAt: createdAt,
      user: user,
      reactions: reactions ?? this.reactions,
      deleted: deleted ?? this.deleted,
      read: read ?? this.read,
    );
  }

  /// Parses both the REST payload (`{id, conversation_id, user, ...}`) and the
  /// broadcast payload from `App\Events\MessageSent` (same shape, flat).
  factory Message.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return Message(id: 0, conversationId: 0, userId: 0, content: '', type: 'text', status: 'sent');
    }
    final replyToRaw = json['reply_to'];
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      status: json['status'] as String? ?? 'sent',
      clientUuid: json['client_uuid'] as String?,
      replyToId: (json['reply_to_id'] as num?)?.toInt(),
      replyTo: replyToRaw is Map<String, dynamic> ? Message.fromReplyTo(replyToRaw) : null,
      forwardedFromMessageId: (json['forwarded_from_message_id'] as num?)?.toInt(),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      mediaStatus: json['media_status'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      user: ChatUser.fromJson(json['user']),
      reactions: _reactionsFrom(json['reactions']),
      deleted: json['deleted'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
    );
  }

  static Message fromReplyTo(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      type: json['attachment_type'] as String? ?? 'text',
      status: 'sent',
      user: ChatUser.fromJson(json['user']),
    );
  }

  static List<ReactionSummary> _reactionsFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map(ReactionSummary.fromJson).toList();
  }
}

class Conversation {
  final int id;
  final String type;
  final String title;
  final CommunityRef? community;
  final ChatUser? otherUser;
  final Message? latestMessage;
  final int unreadCount;
  final DateTime? updatedAt;
  final bool isArchived;
  final bool isMuted;
  final int? memberCount;

  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.community,
    this.otherUser,
    this.latestMessage,
    this.unreadCount = 0,
    this.updatedAt,
    this.isArchived = false,
    this.isMuted = false,
    this.memberCount,
  });

  String? get avatarUrl => otherUser?.avatarUrl ?? community?.logoUrl;
  String get initials {
    final parts = title.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Conversation copyWith({
    Message? latestMessage,
    int? unreadCount,
    DateTime? updatedAt,
    bool? isArchived,
    bool? isMuted,
  }) {
    return Conversation(
      id: id,
      type: type,
      title: title,
      community: community,
      otherUser: otherUser,
      latestMessage: latestMessage ?? this.latestMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      memberCount: memberCount,
    );
  }

  factory Conversation.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return Conversation(id: 0, type: 'direct', title: '');
    }
    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'direct',
      title: json['title'] as String? ?? 'Direct Message',
      community: CommunityRef.fromJson(json['community']),
      otherUser: ChatUser.fromJson(json['other_user']),
      latestMessage: Message.fromJson(json['latest_message']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      isArchived: json['is_archived'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      memberCount: (json['member_count'] as num?)?.toInt(),
    );
  }
}
