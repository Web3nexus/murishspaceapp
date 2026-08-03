import '../models/chat_models.dart';

/// Lightweight date/time formatting for chat UI (no intl dependency).

String formatConversationTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final local = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = now.difference(local);

  if (day == today) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[local.weekday - 1];
  }
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String formatMessageTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Preview text for a message row (emojis/attachments handled).
String messagePreview(Message message) {
  if (message.deleted) return 'This message was deleted';
  if (message.attachmentType == 'image') return '📷 Photo';
  if (message.attachmentType == 'voice') return '🎤 Voice message';
  if (message.attachmentType == 'file') return '📎 File';
  if (message.attachmentType == 'video') return '🎬 Video';
  return message.content;
}
