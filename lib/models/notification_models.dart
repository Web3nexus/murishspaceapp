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
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      data: (json['data'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const {},
      read: json['read_at'] != null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
