/// Model for creator broadcast channels linked to an owned page/group/community.
library;

import 'chat_models.dart';

enum BroadcastLinkedType {
  page,
  group,
  community;

  static BroadcastLinkedType fromApi(String? value) {
    return switch (value) {
      'group' => BroadcastLinkedType.group,
      'community' => BroadcastLinkedType.community,
      _ => BroadcastLinkedType.page,
    };
  }

  String get apiValue => switch (this) {
        BroadcastLinkedType.page => 'page',
        BroadcastLinkedType.group => 'group',
        BroadcastLinkedType.community => 'community',
      };
}

class BroadcastChannel {
  final int id;
  final int userId;
  final String name;
  final String handle;
  final String? description;
  final bool allowReplies;
  final BroadcastLinkedType linkedType;
  final int? linkedId;
  final int recipientsCount;
  final ChatUser? owner;

  const BroadcastChannel({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    this.description,
    this.allowReplies = false,
    this.linkedType = BroadcastLinkedType.page,
    this.linkedId,
    this.recipientsCount = 0,
    this.owner,
  });

  factory BroadcastChannel.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const BroadcastChannel(id: 0, userId: 0, name: '', handle: '');
    }
    return BroadcastChannel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      description: json['description']?.toString(),
      allowReplies: (json['allow_replies'] as bool?) ?? false,
      linkedType: BroadcastLinkedType.fromApi(json['linked_type']?.toString()),
      linkedId: (json['linked_id'] as num?)?.toInt(),
      recipientsCount: (json['recipients_count'] as num?)?.toInt() ?? 0,
      owner: ChatUser.fromJson(json['owner']),
    );
  }
}