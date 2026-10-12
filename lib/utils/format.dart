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
/// Also used for quoted/replied message previews so rich payloads (call JSON,
/// [POLL], [GIFT], [LOCATION]…) never leak raw JSON into the UI.
String messagePreview(Message message) {
  if (message.deleted) return 'This message was deleted';
  final content = message.content.trim();
  final attachment = message.attachmentType?.toLowerCase();
  final type = message.type.toLowerCase();

  final isCall = type == 'call' ||
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

  if (content.startsWith('[LOCATION]') || attachment == 'location') return '📍 Location';
  if (content.startsWith('[COMMUNITY]') || attachment == 'community') return '👥 Community';
  if (content.startsWith('[POLL]') || attachment == 'poll') return '📊 Poll';
  if (content.startsWith('[GIFT]') || type == 'gift' || attachment == 'gift') return '🎁 Gift';
  if (content.startsWith('🔴 Watch ') || attachment == 'live_stream' || type == 'live_stream') {
    return '🔴 Live stream';
  }

  if (attachment == 'image' || type == 'image') return '📷 Photo';
  if (attachment == 'voice' || type == 'voice') return '🎤 Voice message';
  if (attachment == 'file' || type == 'file') return '📎 File';
  if (attachment == 'video' || type == 'video') return '🎬 Video';

  final single = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (single.length > 120) return '${single.substring(0, 120)}…';
  return single;
}

/// Sanitizes an arbitrary notification/title/body string so raw JSON or rich
/// payloads (call JSON, [GIFT], [POLL], [LOCATION], …) never leak into the UI.
/// Safe to call on already-human-readable text (returned unchanged).
String sanitizeNotificationText(String? raw) {
  final content = (raw ?? '').trim();
  if (content.isEmpty) return '';

  if (content.startsWith('[LOCATION]')) return '📍 Location';
  if (content.startsWith('[COMMUNITY]')) return '👥 Community';
  if (content.startsWith('[POLL]')) return '📊 Poll';
  if (content.startsWith('[GIFT]')) return '🎁 Gift';
  if (content.startsWith('🔴 Watch ')) return '🔴 Live stream';

  final looksJson = content.startsWith('{') || content.startsWith('[');
  if (looksJson) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        if (data.containsKey('call_id')) {
          final isVideo = data['call_type'] == 'video';
          final status = (data['status'] as String?) ?? 'ended';
          if (status == 'missed' || status == 'declined') {
            return isVideo ? '📹 Missed Video Call' : '📞 Missed Call';
          }
          final dur = (data['duration'] as num?)?.toInt() ?? 0;
          if (dur > 0) {
            final mins = dur ~/ 60;
            final secs = dur % 60;
            final durStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
            return isVideo ? '📹 Video Call · $durStr' : '📞 Voice Call · $durStr';
          }
          return isVideo ? '📹 Video Call' : '📞 Voice Call';
        }
        if (data.containsKey('message_preview')) {
          return sanitizeNotificationText(data['message_preview']?.toString());
        }
        if (data.containsKey('message')) {
          return sanitizeNotificationText(data['message']?.toString());
        }
        if (data.containsKey('body')) {
          return sanitizeNotificationText(data['body']?.toString());
        }
        if (data.containsKey('text')) {
          return sanitizeNotificationText(data['text']?.toString());
        }
        if (data.containsKey('name')) {
          return data['name']?.toString() ?? 'Notification';
        }
      }
      // Unrecognised valid JSON payload: never render raw object/array.
      return 'Notification';
    } catch (_) {
      // Not valid JSON (e.g. text wrapped in brackets): return original content.
      return content;
    }
  }

  return content;
}


