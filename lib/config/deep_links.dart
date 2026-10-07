import 'dart:convert';

/// Canonical deep-link contract for MurihSpace.
///
/// Every shareable entity has exactly one canonical path shape. The same
/// shapes are served by the web SPA (so a link tapped without the app
/// installed lands on a real page) and claimed by the mobile app on both
/// platforms (so a link tapped with the app installed opens in-app).
///
/// ```
///  content     canonical path   public?   mobile screen
///  ---------   ---------------   -------   ---------------------------
///  live        /live/{token}     yes       LiveLinkScreen
///  meeting     /m/{code}         no        MeetingLinkScreen
///  event       /e/{id}           yes       EventLinkScreen
///  product     /p/{id}           yes       ProductLinkScreen
///  chat        /chat/{id}        no        ConversationScreen
///  profile     /u/{username}     yes       UserProfileScreen
///  community   /c/{slug}         yes       CommunityDetailScreen
///  link-in-bio /l/{username}     yes       LinkInBioScreen
/// ```
///
/// Longer, older shapes stay supported as aliases so links already shared in
/// the wild keep working — see [DeepLinks.resolve].
enum DeepLinkType {
  live,
  meeting,
  event,
  product,
  chat,
  profile,
  community,
  linkInBio,
  storefront,
  unknown,
}

/// A parsed inbound link, normalised to its canonical shape.
class DeepLinkTarget {
  const DeepLinkTarget({
    required this.type,
    required this.identifier,
    this.query = '',
    this.requiresAuth = false,
  });

  final DeepLinkType type;
  final String identifier;
  final String query;
  final bool requiresAuth;

  bool get isUnknown => type == DeepLinkType.unknown;

  /// Canonical in-app location for this target.
  String get appRoute {
    final id = Uri.encodeComponent(identifier);
    final suffix = query.isEmpty ? '' : '?$query';
    switch (type) {
      case DeepLinkType.live:
        return '/live/$id$suffix';
      case DeepLinkType.meeting:
        return '/m/$id$suffix';
      case DeepLinkType.event:
        return '/e/$id$suffix';
      case DeepLinkType.product:
        return '/p/$id$suffix';
      case DeepLinkType.chat:
        return '/app/conversation/$id$suffix';
      case DeepLinkType.profile:
        return '/u/$id$suffix';
      case DeepLinkType.community:
        return '/c/$id$suffix';
      case DeepLinkType.linkInBio:
        return '/l/$id$suffix';
      case DeepLinkType.storefront:
        return '/store/$id$suffix';
      case DeepLinkType.unknown:
        return '/app/home';
    }
  }

  @override
  String toString() => 'DeepLinkTarget(${type.name}, $identifier)';
}

/// Path builders, parsers and the app/web link contract.
///
/// Keep this in sync with `web/frontend/src/lib/deepLinks.ts`.
class DeepLinks {
  const DeepLinks._();

  /// Android package name and iOS bundle id. Must match
  /// `assetlinks.json` / `apple-app-site-association`.
  static const String appId = 'com.murihspace.mobile';

  /// Custom scheme. Legacy only — never emit this when sharing.
  static const String scheme = 'murihspace';

  // ── Canonical web paths ──────────────────────────────────────────
  static const String livePath = '/live';
  static const String meetingPath = '/m';
  static const String eventPath = '/e';
  static const String productPath = '/p';
  static const String chatPath = '/chat';
  static const String profilePath = '/u';
  static const String communityPath = '/c';
  static const String linkInBioPath = '/l';
  static const String storefrontPath = '/store';

  /// Every first path segment the app claims on Android / iOS.
  ///
  /// iOS scopes Universal Links with the path patterns in the AASA
  /// `components` array, so both platforms are path-scoped and this list keeps
  /// the two in step. It is the source for the Android intent-filter
  /// `pathPrefix` entries and must stay aligned with
  /// `AndroidManifest.xml` and `web/frontend/public/.well-known/`.
  ///
  /// Only include prefixes the app can genuinely route: claiming a path it
  /// cannot handle opens a dead screen instead of the web page.
  static const List<String> appClaimedPrefixes = [
    livePath,
    meetingPath,
    eventPath,
    productPath,
    chatPath,
    profilePath,
    communityPath,
    linkInBioPath,
    storefrontPath,
  ];

  // ── Builders ─────────────────────────────────────────────────────
  /// Normalises a handle for use in a path segment.
  static String handle(String username) =>
      username.trim().replaceFirst(RegExp(r'^@'), '');

  static String live(String token) => '$livePath/${Uri.encodeComponent(token)}';

  static String meeting(String code) =>
      '$meetingPath/${Uri.encodeComponent(code.trim().toLowerCase())}';

  static String event(dynamic id) => '$eventPath/${Uri.encodeComponent('$id')}';

  static String product(dynamic id) =>
      '$productPath/${Uri.encodeComponent('$id')}';

  static String chat(dynamic conversationId) =>
      '$chatPath/${Uri.encodeComponent('$conversationId')}';

  static String profile(String username) =>
      '$profilePath/${Uri.encodeComponent(handle(username))}';

  static String community(String slug) =>
      '$communityPath/${Uri.encodeComponent(slug.trim())}';

  static String linkInBio(String username) =>
      '$linkInBioPath/${Uri.encodeComponent(handle(username))}';

  static String storefront(String shortCode) =>
      '$storefrontPath/${Uri.encodeComponent(shortCode.trim())}';

  // ── Parser ───────────────────────────────────────────────────────

  /// Normalises an inbound link to `[scheme, host, path, query]`.
  ///
  /// Accepts every shape the OS can hand us:
  ///   `https://web.murihspace.com/live/abc?x=1`
  ///   `murihspace://live/abc`, `murihspace:///live/abc`, `murihspace:live/abc`
  ///   `/live/abc`  (relative push from inside the app)
  ///   `web.murihspace.com/live/abc`  (copied without a scheme)
  static Uri normalise(String raw) {
    var input = raw.trim();
    if (input.isEmpty) return Uri(path: '/');

    if (input.toLowerCase().startsWith('$scheme://')) {
      input = input.substring(scheme.length + 3);
    } else if (input.toLowerCase().startsWith('$scheme:')) {
      input = input.substring(scheme.length + 1);
    }

    if (input.startsWith('/')) return Uri.parse(input);

    // A scheme we don't recognise is an outbound link, not a deep link.
    final schemeMatch = RegExp(
      r'^([a-zA-Z][a-zA-Z0-9+.-]*):',
    ).firstMatch(input);
    if (schemeMatch != null &&
        !RegExp(r'^https?$').hasMatch(schemeMatch.group(1)!)) {
      return Uri(path: '/');
    }

    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(input)) {
      if (!input.contains('.')) return Uri.parse('/$input');
      input = 'https://$input';
    }

    final parsed = Uri.tryParse(input);
    if (parsed == null) return Uri(path: '/');

    // Only MurihSpace hosts are ours. Anything else — `https://evil.example/
    // live/abc` — is an outbound link that happens to share a path shape, and
    // resolving it would send the user to content they did not come from us on.
    final host = parsed.host.toLowerCase();
    if (host.isNotEmpty &&
        host != 'murihspace.com' &&
        !host.endsWith('.murihspace.com')) {
      return Uri(path: '/');
    }

    return Uri(
      path: parsed.path,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    );
  }

  /// Resolves any inbound link into a canonical [DeepLinkTarget].
  ///
  /// Recognises canonical shapes first, then legacy aliases. Returns an
  /// `unknown` target when nothing matches so callers can fall back to the
  /// home screen rather than throwing.
  static DeepLinkTarget resolve(String raw, {bool query = false}) {
    final uri = normalise(raw);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final rawQuery = query || uri.hasQuery ? uri.query : '';

    if (segments.isEmpty) {
      return DeepLinkTarget(type: DeepLinkType.unknown, identifier: '');
    }

    String? id(List<String> parts, [int index = 1]) =>
        index < parts.length && parts[index].isNotEmpty ? parts[index] : null;

    final first = segments.first;
    final second = segments.length > 1 ? segments[1] : '';

    // Canonical short forms.
    if (first == 'm' || first == 'meeting' || first == 'meetings') {
      final code = id(segments);
      if (code != null && code != 'instant') {
        return DeepLinkTarget(
          type: DeepLinkType.meeting,
          identifier: code.toLowerCase(),
          query: rawQuery,
          requiresAuth: true,
        );
      }
    } else if (first == 'e') {
      final eventId = id(segments);
      if (eventId != null) {
        return DeepLinkTarget(
          type: DeepLinkType.event,
          identifier: eventId,
          query: rawQuery,
        );
      }
    } else if (first == 'p') {
      final productId = id(segments);
      if (productId != null) {
        return DeepLinkTarget(
          type: DeepLinkType.product,
          identifier: productId,
          query: rawQuery,
        );
      }
    } else if (first == 'chat') {
      final conversationId = id(segments);
      if (conversationId != null) {
        return DeepLinkTarget(
          type: DeepLinkType.chat,
          identifier: conversationId,
          query: rawQuery,
          requiresAuth: true,
        );
      }
    } else if (first == 'l' || first == 'bio') {
      final username = id(segments);
      if (username != null) {
        return DeepLinkTarget(
          type: DeepLinkType.linkInBio,
          identifier: handle(username),
          query: rawQuery,
        );
      }
    } else if (first == 'c' || first == 'communities') {
      final slug = id(segments);
      if (slug != null) {
        return DeepLinkTarget(
          type: DeepLinkType.community,
          identifier: slug,
          query: rawQuery,
        );
      }
    } else if (first == 'u') {
      final username = id(segments);
      if (username != null) {
        return DeepLinkTarget(
          type: DeepLinkType.profile,
          identifier: handle(username),
          query: rawQuery,
        );
      }
    } else if (first == 'live') {
      // /live/{token} and the legacy /live/resolve/{token}
      final token = second == 'resolve' ? id(segments, 2) : id(segments);
      if (token != null) {
        return DeepLinkTarget(
          type: DeepLinkType.live,
          identifier: token,
          query: rawQuery,
        );
      }
    } else if (first == 'store') {
      // /store/{shortCode} and /store/{shortCode}/p/{productId}
      final shortCode = id(segments);
      if (shortCode != null) {
        // ['store', shortCode, 'p', productId] — the id is the fourth segment.
        if (segments.length > 3 && segments[2] == 'p') {
          return DeepLinkTarget(
            type: DeepLinkType.product,
            identifier: segments[3],
            query: rawQuery,
          );
        }
        return DeepLinkTarget(
          type: DeepLinkType.storefront,
          identifier: shortCode,
          query: rawQuery,
        );
      }
    }

    // Legacy /app-prefixed aliases.
    if (first == 'app' && segments.length > 2) {
      final section = segments[1];
      final value = segments[2];
      if (section == 'live') {
        final tracking = uri.queryParameters['trackingId'];
        if (tracking != null && tracking.isNotEmpty) {
          return DeepLinkTarget(
            type: DeepLinkType.live,
            identifier: tracking,
            query: rawQuery,
          );
        }
      } else if (section == 'meeting' ||
          (section == 'meetings' && value != 'instant')) {
        return DeepLinkTarget(
          type: DeepLinkType.meeting,
          identifier: value.toLowerCase(),
          query: rawQuery,
          requiresAuth: true,
        );
      } else if (section == 'events') {
        return DeepLinkTarget(
          type: DeepLinkType.event,
          identifier: value,
          query: rawQuery,
        );
      } else if (section == 'conversation') {
        return DeepLinkTarget(
          type: DeepLinkType.chat,
          identifier: value,
          query: rawQuery,
          requiresAuth: true,
        );
      } else if (section == 'community') {
        return DeepLinkTarget(
          type: DeepLinkType.community,
          identifier: value,
          query: rawQuery,
        );
      }
    }

    // Top-level legacy aliases.
    if (first == 'events') {
      final eventId = id(segments);
      if (eventId != null && eventId != 'my') {
        return DeepLinkTarget(
          type: DeepLinkType.event,
          identifier: eventId,
          query: rawQuery,
        );
      }
    } else if (first == 'products') {
      final productId = id(segments);
      if (productId != null) {
        return DeepLinkTarget(
          type: DeepLinkType.product,
          identifier: productId,
          query: rawQuery,
        );
      }
    } else if (first == 'conversation') {
      final conversationId = id(segments);
      if (conversationId != null) {
        return DeepLinkTarget(
          type: DeepLinkType.chat,
          identifier: conversationId,
          query: rawQuery,
          requiresAuth: true,
        );
      }
    } else if (first == 'community') {
      final slug = id(segments);
      if (slug != null) {
        return DeepLinkTarget(
          type: DeepLinkType.community,
          identifier: slug,
          query: rawQuery,
        );
      }
    }

    return const DeepLinkTarget(type: DeepLinkType.unknown, identifier: '');
  }

  /// Whether [path] is a location the app is allowed to navigate back to
  /// after authentication.
  ///
  /// Guards against open-redirect style abuse: only canonical in-app routes
  /// are honoured, never absolute URLs.
  static bool isReturnableRoute(String path) {
    if (!path.startsWith('/') || path.startsWith('//')) return false;
    if (path.contains('\\')) return false;

    // Anything under the app shell or a known entity prefix is fine, as long
    // as it cannot be mistaken for a different scheme.
    final lower = path.toLowerCase();
    for (final prefix in appClaimedPrefixes) {
      if (lower == prefix || lower.startsWith('$prefix/')) return true;
    }
    const appPrefixes = <String>[
      '/app/',
      '/profile/',
      '/conversation/',
      '/community/',
      '/communities/',
      '/events/',
      '/products/',
      '/meeting',
      '/meetings/',
    ];
    for (final prefix in appPrefixes) {
      if (lower == prefix.trimRight() || lower.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Sanitises a `returnTo` value, returning null when it is not safe.
  static String? sanitiseReturnTo(String? value) {
    if (value == null || value.isEmpty) return null;
    var candidate = value.trim();
    if (candidate.isEmpty) return null;
    if (!candidate.startsWith('/') || candidate.startsWith('//')) return null;
    // `/\evil.com` and similar are rejected by isReturnableRoute.
    if (!isReturnableRoute(candidate)) return null;
    // Cap the length so a hostile link cannot bloat the URL.
    if (candidate.length > 2048) return null;
    candidate = candidate.replaceAll('\\', '/');
    return candidate;
  }

  // ── Opaque live token codec ──────────────────────────────────────

  /// Encodes a `streamId[:hostUserId]` pair into the opaque live-link token
  /// used when a stream has no `tracking_id` yet.
  static String encodeLiveToken(int streamId, {int? hostUserId}) {
    final payload = hostUserId != null && hostUserId > 0
        ? '$streamId:$hostUserId'
        : '$streamId';
    return base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  }
}
