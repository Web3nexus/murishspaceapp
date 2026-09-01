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
  final bool isOnline;
  final String? lastSeen;

  const ChatUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.isOnline = true,
    this.lastSeen = 'online',
  });

  factory ChatUser.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const ChatUser(id: 0, name: '', username: '');
    return ChatUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: (json['avatar_url'] ?? json['avatar'])?.toString(),
      isOnline: (json['is_online'] as bool?) ?? (json['isOnline'] as bool?) ?? true,
      lastSeen: json['last_seen']?.toString() ?? json['lastSeen']?.toString() ?? 'online',
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
      name: json['name']?.toString(),
      slug: json['slug']?.toString(),
      logoUrl: json['logo_url']?.toString(),
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
      return const Message(id: 0, conversationId: 0, userId: 0, content: '', type: 'text', status: 'sent');
    }
    final replyToRaw = json['reply_to'];
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      status: json['status']?.toString() ?? 'sent',
      clientUuid: json['client_uuid']?.toString(),
      replyToId: (json['reply_to_id'] as num?)?.toInt(),
      replyTo: replyToRaw is Map<String, dynamic> ? Message.fromReplyTo(replyToRaw) : null,
      forwardedFromMessageId: (json['forwarded_from_message_id'] as num?)?.toInt(),
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentType: json['attachment_type']?.toString(),
      mediaStatus: json['media_status']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      user: ChatUser.fromJson(json['user']),
      reactions: _reactionsFrom(json['reactions']),
      deleted: (json['deleted'] as bool?) ?? false,
      read: (json['read'] as bool?) ?? false,
    );
  }

  static Message fromReplyTo(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      content: json['content']?.toString() ?? '',
      type: json['attachment_type']?.toString() ?? 'text',
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
  final bool isPinned;
  final int? memberCount;
  final bool hasActiveEscrow;
  final double? escrowAmount;
  final String? escrowCurrency;

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
    this.isPinned = false,
    this.memberCount,
    this.hasActiveEscrow = false,
    this.escrowAmount,
    this.escrowCurrency = 'USD',
  });

  String? get avatarUrl => otherUser?.avatarUrl ?? community?.logoUrl;
  String get initials {
    final t = title.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
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
    bool? isPinned,
    bool? hasActiveEscrow,
    double? escrowAmount,
    String? escrowCurrency,
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
      isPinned: isPinned ?? this.isPinned,
      memberCount: memberCount,
      hasActiveEscrow: hasActiveEscrow ?? this.hasActiveEscrow,
      escrowAmount: escrowAmount ?? this.escrowAmount,
      escrowCurrency: escrowCurrency ?? this.escrowCurrency,
    );
  }

  factory Conversation.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const Conversation(id: 0, type: 'direct', title: 'Direct Message');
    }
    final other = ChatUser.fromJson(json['other_user']);
    final rawTitle = json['title']?.toString();
    final effectiveTitle = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (other.name.isNotEmpty ? other.name : 'Direct Message');

    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'direct',
      title: effectiveTitle,
      community: CommunityRef.fromJson(json['community']),
      otherUser: other,
      latestMessage: json['latest_message'] != null ? Message.fromJson(json['latest_message']) : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      isArchived: (json['is_archived'] as bool?) ?? false,
      isMuted: (json['is_muted'] as bool?) ?? false,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      memberCount: (json['member_count'] as num?)?.toInt(),
      hasActiveEscrow: (json['has_active_escrow'] as bool?) ?? (json['escrow_amount'] != null),
      escrowAmount: (json['escrow_amount'] as num?)?.toDouble(),
      escrowCurrency: json['escrow_currency']?.toString() ?? 'USD',
    );
  }
}
