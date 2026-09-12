/// Models for in-app notifications, parsed from the Laravel database
/// notification payloads (`data` holds the app-specific payload map).
library;

class AppNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.data = const {},
    this.read = false,
    this.createdAt,
  });

  String? get senderName => data['sender_name']?.toString();
  String? get messagePreview => data['message_preview']?.toString();
  int? get conversationId => (data['conversation_id'] as num?)?.toInt();
  String? get notificationType => data['type']?.toString() ?? type.split('.').last;
  String get title => data['title']?.toString() ?? (isOfficial ? 'Murih Notifications Official' : senderName ?? data['name']?.toString() ?? 'Notification');
  String get body => data['body']?.toString() ?? data['message']?.toString() ?? messagePreview ?? '';
  String? get route => data['route']?.toString() ?? data['action_url']?.toString();
  String? get actionLabel => data['action_label']?.toString();

  bool get isOfficial =>
      data['is_official'] == true ||
      senderName == 'Murih Notifications Official' ||
      notificationType == 'role_upgrade_approved' ||
      notificationType == 'role_upgrade_rejected' ||
      notificationType == 'kyc_approved' ||
      notificationType == 'kyc_rejected' ||
      notificationType == 'kyc_requested' ||
      notificationType == 'gift_received' ||
      notificationType == 'money_received';

  bool get isVerified => data['is_verified'] == true || isOfficial;

  String get officialSenderName => senderName ?? 'Murih Notifications Official';

  factory AppNotification.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const AppNotification(id: '', type: '');
    }
    // Database notifications keep their payload under `data`; live Reverb
    // broadcasts (NotificationBroadcast / Laravel broadcast notifications) put
    // the payload keys at the top level, so merge the relevant ones.
    final data = (json['data'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final merged = <String, dynamic>{
      ...data,
      if (json['type'] != null) 'type': json['type'],
      if (json['title'] != null) 'title': json['title'],
      if (json['message'] != null) 'message': json['message'],
      if (json['body'] != null) 'body': json['body'],
      if (json['route'] != null) 'route': json['route'],
      if (json['action_url'] != null) 'action_url': json['action_url'],
      if (json['sender_name'] != null) 'sender_name': json['sender_name'],
      if (json['sender_id'] != null) 'sender_id': json['sender_id'],
      if (json['conversation_id'] != null) 'conversation_id': json['conversation_id'],
      if (json['message_preview'] != null) 'message_preview': json['message_preview'],
      if (json['is_official'] != null) 'is_official': json['is_official'],
      if (json['is_verified'] != null) 'is_verified': json['is_verified'],
    };
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      data: merged,
      read: json['read_at'] != null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
