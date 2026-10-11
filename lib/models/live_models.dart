/// Models for live broadcast discovery.
///
/// `GET /live` returns a Laravel paginator whose rows are `LiveStream` models
/// eager-loaded with `host` (`User`) and `community`. There is no thumbnail
/// column, so clients render branded placeholder art from the host identity.
library;

import 'chat_models.dart';

class LiveCommunityRef {
  final int? id;
  final String name;
  final String? slug;

  const LiveCommunityRef({this.id, required this.name, this.slug});

  factory LiveCommunityRef.fromJson(dynamic json) {
    if (json is! Map) return const LiveCommunityRef(name: '');
    final map = Map<String, dynamic>.from(json);
    return LiveCommunityRef(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString(),
    );
  }
}

class LiveStream {
  final int id;
  final String trackingId;
  final String title;
  final String? description;
  final String streamMode;
  final String status;
  final int viewersCount;
  final int likesCount;
  final int totalCoinsEarned;
  final DateTime? startedAt;
  final ChatUser? host;
  final LiveCommunityRef? community;

  const LiveStream({
    required this.id,
    required this.trackingId,
    required this.title,
    this.description,
    this.streamMode = 'video',
    this.status = 'live',
    this.viewersCount = 0,
    this.likesCount = 0,
    this.totalCoinsEarned = 0,
    this.startedAt,
    this.host,
    this.community,
  });

  bool get isLive => status == 'live';
  bool get isAudioOnly => streamMode == 'audio' || streamMode == 'meeting';

  /// Live runtime in minutes, derived from the server start timestamp.
  int get elapsedMinutes {
    final started = startedAt;
    if (started == null) return 0;
    final diff = DateTime.now().difference(started.toLocal());
    return diff.isNegative ? 0 : diff.inMinutes;
  }

  String get elapsedLabel {
    final minutes = elapsedMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  factory LiveStream.fromJson(dynamic json) {
    if (json is! Map) {
      return const LiveStream(id: 0, trackingId: '', title: '');
    }
    final map = Map<String, dynamic>.from(json);
    final hostJson = map['host'];
    final communityJson = map['community'];
    return LiveStream(
      id: (map['id'] as num?)?.toInt() ?? 0,
      trackingId: map['tracking_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      streamMode: map['stream_mode']?.toString() ?? 'video',
      status: map['status']?.toString() ?? 'live',
      viewersCount: (map['viewers_count'] as num?)?.toInt() ?? 0,
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      totalCoinsEarned: (map['total_coins_earned'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? ''),
      host: hostJson is Map ? ChatUser.fromJson(hostJson) : null,
      community: communityJson is Map
          ? LiveCommunityRef.fromJson(communityJson)
          : null,
    );
  }
}
