import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// A MurihSpace event.
///
/// Mirrors the shape returned by `GET /api/v1/events/{id}` and
/// `GET /api/v1/events`, which the web dashboard and the public `/e/:id` share
/// page both consume — so an event describes identically on every surface.
@immutable
class EventModel {
  final int id;
  final String title;
  final String? slug;
  final String? description;
  final String eventType; // online | in_person | hybrid
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timezone;
  final String? location;
  final String? meetingUrl;
  final String? coverUrl;
  final int? capacity;
  final DateTime? registrationDeadline;
  final String status;
  final bool isFeatured;
  final int? communityId;
  final String? communityName;
  final String? communitySlug;
  final int? creatorId;
  final String? creatorName;
  final String? creatorUsername;
  final String? creatorAvatar;
  final int registrationCount;
  final bool isFull;
  final bool isRegistrationOpen;
  final bool isRegistered;

  const EventModel({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    this.eventType = 'online',
    this.startDate,
    this.endDate,
    this.timezone,
    this.location,
    this.meetingUrl,
    this.coverUrl,
    this.capacity,
    this.registrationDeadline,
    this.status = 'published',
    this.isFeatured = false,
    this.communityId,
    this.communityName,
    this.communitySlug,
    this.creatorId,
    this.creatorName,
    this.creatorUsername,
    this.creatorAvatar,
    this.registrationCount = 0,
    this.isFull = false,
    this.isRegistrationOpen = true,
    this.isRegistered = false,
  });

  bool get isPast {
    final end = endDate ?? startDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  bool get isOnline => eventType == 'online' || eventType == 'hybrid';

  String get typeLabel => switch (eventType) {
    'in_person' => 'In person',
    'hybrid' => 'Hybrid',
    _ => 'Online',
  };

  /// The canonical in-app path for this event, used for share and navigation.
  String get sharePath => '/e/$id';

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final community = json['community'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;
    return EventModel(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? 'MurihSpace Event').toString(),
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      eventType: (json['event_type'] ?? 'online').toString(),
      startDate: _asDate(json['start_date']),
      endDate: _asDate(json['end_date']),
      timezone: json['timezone']?.toString(),
      location: json['location']?.toString(),
      meetingUrl: json['meeting_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      capacity: _asInt(json['capacity']),
      registrationDeadline: _asDate(json['registration_deadline']),
      status: (json['status'] ?? 'published').toString(),
      isFeatured: json['is_featured'] == true,
      communityId: _asInt(json['community_id']),
      communityName: community?['name']?.toString(),
      communitySlug: community?['slug']?.toString(),
      creatorId: _asInt(creator?['id']) ?? _asInt(json['creator_id']),
      creatorName: creator?['name']?.toString(),
      creatorUsername: creator?['username']?.toString(),
      creatorAvatar: (creator?['avatar'] ?? creator?['avatar_url'])?.toString(),
      registrationCount: _asInt(json['registration_count']) ?? 0,
      isFull: json['is_full'] == true,
      isRegistrationOpen: json['is_registration_open'] != false,
      isRegistered: json['is_registered'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'slug': slug,
    'description': description,
    'event_type': eventType,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'timezone': timezone,
    'location': location,
    'meeting_url': meetingUrl,
    'cover_url': coverUrl,
    'capacity': capacity,
    'registration_deadline': registrationDeadline?.toIso8601String(),
    'status': status,
    'is_featured': isFeatured,
    'community_id': communityId,
    'community_name': communityName,
    'community_slug': communitySlug,
    'creator_id': creatorId,
    'creator_name': creatorName,
    'creator_username': creatorUsername,
    'creator_avatar': creatorAvatar,
    'registration_count': registrationCount,
    'is_full': isFull,
    'is_registration_open': isRegistrationOpen,
    'is_registered': isRegistered,
  };

  @override
  bool operator ==(Object other) => other is EventModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EventModel($id, $title)';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Upcoming events, optionally narrowed by the server-side `filter` param
/// (`upcoming` | `past` | `my_communities`).
/// Upcoming published events.
///
/// The endpoint hardcodes `published()->upcoming()` and `paginate(20)`, so the
/// only filter it honours is `community_id` — there is deliberately no client
/// side "past events" tab, because the response only ever contains the next 20
/// upcoming events and filtering them locally would silently hide older ones.
final eventsProvider = FutureProvider.autoDispose
    .family<List<EventModel>, int?>((ref, communityId) {
      final api = ref.read(apiClientProvider);
      return api
          .get('/events', queryParameters: {'community_id': ?communityId})
          .then((response) => api.unwrapList(response, EventModel.fromJson));
    });

/// A single event, addressed by the segment captured from `/e/:id`.
///
/// The API's `show(int $id)` is typed, so a numeric segment goes straight to
/// `/events/{id}`. A non-numeric segment is treated as a legacy slug and
/// resolved against the upcoming list instead, which keeps older slug links
/// working without pretending the endpoint supports slug lookup.
final eventProvider = FutureProvider.autoDispose.family<EventModel, String>((
  ref,
  id,
) {
  final segment = id.trim();
  if (segment.isEmpty) {
    throw ApiException(message: 'This event link is missing an event.');
  }

  final api = ref.read(apiClientProvider);
  if (int.tryParse(segment) != null) {
    return api.get('/events/${Uri.encodeComponent(segment)}').then((response) {
      return EventModel.fromJson(_requireEventPayload(api, response.data));
    });
  }

  final slug = segment.toLowerCase();
  return api.get('/events').then((response) {
    final events = api.unwrapList(response, EventModel.fromJson);
    final match = events.where((event) => event.slug?.toLowerCase() == slug);
    if (match.isEmpty) {
      throw ApiException(message: 'This event is no longer available.');
    }
    return match.first;
  });
});

/// Events the signed-in user created. Requires the `creator` role.
final myEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) {
  final api = ref.read(apiClientProvider);
  return api
      .get('/my-events')
      .then((response) => api.unwrapList(response, EventModel.fromJson));
});

/// Upcoming events the signed-in user is registered for.
///
/// `/my-registrations` returns `EventRegistration` rows, so each row's nested
/// `event` is unwrapped here rather than being parsed as an event itself.
final myUpcomingEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) {
  final api = ref.read(apiClientProvider);
  return api.get('/my-registrations').then((response) {
    final rows = api.unwrapList(
      response,
      (json) => (json['event'] as Map<String, dynamic>?),
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  });
});

Map<String, dynamic> _requireEventPayload(ApiClient api, dynamic body) {
  final payload = body is Map<String, dynamic> ? body : null;
  final raw = payload == null
      ? null
      : (payload['event'] ?? payload['data'] ?? payload);
  if (raw is! Map<String, dynamic>) {
    throw ApiException(message: 'This event is no longer available.');
  }
  return raw;
}

@immutable
class EventRegistrationState {
  final Set<int> registeredIds;
  final bool loading;
  final String? error;
  final int? mutatingId;

  const EventRegistrationState({
    this.registeredIds = const {},
    this.loading = false,
    this.error,
    this.mutatingId,
  });

  bool isRegistered(int eventId) => registeredIds.contains(eventId);

  EventRegistrationState copyWith({
    Set<int>? registeredIds,
    bool? loading,
    String? error,
    int? mutatingId,
    bool clearMutating = false,
  }) {
    return EventRegistrationState(
      registeredIds: registeredIds ?? this.registeredIds,
      loading: loading ?? this.loading,
      error: error,
      mutatingId: clearMutating ? null : (mutatingId ?? this.mutatingId),
    );
  }
}

final eventRegistrationProvider =
    NotifierProvider<EventRegistrationNotifier, EventRegistrationState>(
      EventRegistrationNotifier.new,
    );

/// Registration actions for events.
///
/// Keeps the registered-id set in memory so a detail screen can flip its button
/// immediately on tap rather than waiting for a refetch, and refetches the event
/// afterwards so the remaining capacity shown to the user stays accurate.
///
/// Note: `register` is behind the API's `verified` middleware, so an
/// unverified account gets a 403 here. That message is surfaced verbatim rather
/// than replaced with a generic failure.
class EventRegistrationNotifier extends Notifier<EventRegistrationState> {
  @override
  EventRegistrationState build() => const EventRegistrationState();

  /// [cacheKey] is the route segment the detail screen is keyed by, which is a
  /// slug on older links. Without it a registration made from a slug link
  /// invalidates only the numeric key and leaves the screen showing the state
  /// it had before the request.
  Future<bool> register(int eventId, {String? cacheKey}) =>
      _toggle(eventId, 'register', cacheKey);

  Future<bool> cancel(int eventId, {String? cacheKey}) =>
      _toggle(eventId, 'cancel', cacheKey);

  Future<bool> _toggle(int eventId, String action, String? cacheKey) async {
    if (state.mutatingId != null) return false;
    state = state.copyWith(mutatingId: eventId, error: null);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/events/$eventId/$action');
      api.unwrap(response); // throws on an API-level failure
      final next = {...state.registeredIds};
      if (action == 'register') {
        next.add(eventId);
      } else {
        next.remove(eventId);
      }
      state = state.copyWith(registeredIds: next, clearMutating: true);
      final numericKey = eventId.toString();
      ref.invalidate(eventProvider(numericKey));
      final segment = cacheKey?.trim() ?? '';
      if (segment.isNotEmpty && segment != numericKey) {
        ref.invalidate(eventProvider(segment));
      }
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(clearMutating: true, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        clearMutating: true,
        error: 'Could not update your registration.',
      );
      return false;
    }
  }

  /// Adopts a registration flag that was already present on a fetched event.
  void seed(EventModel event) {
    if (event.isRegistered && !state.registeredIds.contains(event.id)) {
      state = state.copyWith(registeredIds: {...state.registeredIds, event.id});
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }
}
