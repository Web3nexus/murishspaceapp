import 'dart:convert';
import '../models/chat_models.dart';

/// Lightweight date/time formatting for chat UI (no intl dependency).

String formatRelativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.toLocal().day}/${dt.toLocal().month}/${dt.toLocal().year}';
}

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
  final content = message.content.trim();
  final isCall = message.type == 'call' ||
      content.startsWith('{"call_id"') ||
      (content.startsWith('{') && content.contains('"call_id"'));
  if (isCall) {
    try {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      final isVideo = data['call_type'] == 'video';
      final status = (data['status'] as String?) ?? 'ended';
      final isMissed = status == 'missed' || status == 'declined';
      if (isMissed) return isVideo ? '📹 Missed Video Call' : '📞 Missed Call';
      final dur = (data['duration'] as num?)?.toInt() ?? 0;
      if (dur > 0) {
        final mins = dur ~/ 60;
        final secs = dur % 60;
        final durStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        return isVideo ? '📹 Video Call · $durStr' : '📞 Voice Call · $durStr';
      }
      return isVideo ? '📹 Video Call' : '📞 Voice Call';
    } catch (_) {
      return '📞 Call';
    }
  }
  if (message.attachmentType == 'image') return '📷 Photo';
  if (message.attachmentType == 'voice') return '🎤 Voice message';
  if (message.attachmentType == 'file') return '📎 File';
  if (message.attachmentType == 'video') return '🎬 Video';
  return message.content;
}

