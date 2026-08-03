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

  String? get senderName => data['sender_name'] as String?;
  String? get messagePreview => data['message_preview'] as String?;
  int? get conversationId => (data['conversation_id'] as num?)?.toInt();
  String? get notificationType => data['type'] as String? ?? type.split('.').last;

  factory AppNotification.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const AppNotification(id: '', type: '');
    }
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const {},
      read: json['read_at'] != null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
