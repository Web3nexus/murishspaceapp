import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

import 'deep_links.dart';

/// Resolves which API backend (and Reverb cluster) the app talks to.
///
/// Resolution order:
///  1. `--dart-define=API_BASE_URL=...` — explicit override (LAN IP,
///     tunnel, anything). Highest priority, always wins.
///  2. `--dart-define=API_ENV=production|staging` — a named environment
///     mapped to a hosted URL.
///  3. In Release/Archive mode (e.g. Xcode Archive or TestFlight), defaults
///     to `production` (https://api.murihspace.com/api/v1).
///  4. Local fallback in debug mode for emulator/simulator:
///       - Android emulator -> http://10.0.2.2:8000/api/v1
///       - everything else   -> http://127.0.0.1:8000/api/v1
///
/// Other build-time defines:
///  - `ADS_MANAGER_URL` — Web Ads Manager link. No default; when unset, the
///    "View full stats on web" button on the Ads screen is hidden.
///    e.g. `flutter build apk --dart-define=ADS_MANAGER_URL=https://ads.example.com`
///
/// To archive or run against staging:
///   `flutter build ipa --dart-define=API_ENV=staging`
/// To archive or run against production:
///   `flutter build ipa --dart-define=API_ENV=production`
class Env {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'MurihSpace',
  );

  static const String _explicitBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Web Ads Manager, where full campaign stats are viewed after logging in.
  /// Set with `--dart-define=ADS_MANAGER_URL=https://...`. There is no
  /// built-in default: when empty, the "View full stats on web" button is hidden.
  static const String adsManagerUrl = String.fromEnvironment('ADS_MANAGER_URL');

  /// LiveKit server (wss://...). Set with `--dart-define=LIVEKIT_URL=wss://...`. There is no
  /// built-in default: calls and live streams refuse to connect when it is empty.
  static const String livekitUrl = String.fromEnvironment('LIVEKIT_URL');

  static const String _rawApiEnv = String.fromEnvironment('API_ENV');

  static String? _runtimeEnvOverride;

  /// Allows runtime switching of backend environment.
  static void setRuntimeEnv(String? env) {
    _runtimeEnvOverride = env;
  }

  /// Resolves the active environment name (`staging`, `production`, or `local`).
  static String get apiEnv {
    if (_runtimeEnvOverride != null && _runtimeEnvOverride!.isNotEmpty) {
      return _runtimeEnvOverride!;
    }
    if (_rawApiEnv.isNotEmpty) return _rawApiEnv;
    // Default to staging for current active staging testing
    return 'staging';
  }

  static const String _stagingBaseUrl =
      'https://api-staging.murihspace.com/api/v1';
  static const String _productionBaseUrl = 'https://api.murihspace.com/api/v1';

  static const String _stagingWebUrl = 'https://staging.murihspace.com';
  static const String _productionWebUrl = 'https://web.murihspace.com';

  /// Resolves the primary frontend domain based on environment.
  static String get webBaseUrl {
    const explicit = String.fromEnvironment('WEB_BASE_URL');
    if (explicit.isNotEmpty) return explicit;

    if (_explicitBaseUrl.isNotEmpty) {
      final parsed = Uri.tryParse(_explicitBaseUrl);
      if (parsed != null && parsed.host.isNotEmpty) {
        return '${parsed.scheme}://${parsed.host}${parsed.hasPort && parsed.port != 80 && parsed.port != 443 ? ":${parsed.port}" : ""}';
      }
    }

    switch (apiEnv) {
      case 'staging':
        return _stagingWebUrl;
      case 'production':
      case 'prod':
        return _productionWebUrl;
      case 'local':
      default:
        return _productionWebUrl;
    }
  }

  static String get livePublicUrl {
    const explicit = String.fromEnvironment('LIVE_PUBLIC_URL');
    if (explicit.isNotEmpty) return explicit.replaceAll(RegExp(r'/+$'), '');

    return webBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  static String? _runtimeProfileDomain;
  static String? _cachedProfileDomain;

  static const String _profileDomainKey = 'canonical_profile_domain';

  /// Records the canonical profile domain the backend reports (`/platform`).
  /// It is kept in memory and on the device, so links still work on a cold
  /// start before the network answers.
  static void setRuntimeProfileDomain(String? domain) {
    final clean = _cleanDomain(domain);
    if (clean == null) return;
    _runtimeProfileDomain = clean;
    _cachedProfileDomain = clean;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_profileDomainKey, clean))
        .ignore();
  }

  /// Loads the last canonical profile domain saved on this device. Call once at
  /// startup, before any screen builds a profile or bio link.
  static Future<void> restoreProfileDomain() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedProfileDomain = _cleanDomain(prefs.getString(_profileDomainKey));
  }

  static String? _cleanDomain(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  /// Host that serves vanity profile and link-in-bio pages (bare, no scheme).
  ///
  /// Comes from the backend's `canonical_profile_domain` setting, never from a
  /// built-in guess. Resolution: the value from the backend this session, then
  /// the last value saved on the device, then an explicit
  /// `--dart-define=PROFILE_DOMAIN=...` for local builds. Returns an empty
  /// string until one of them is known.
  static String get profileDomain {
    if (_runtimeProfileDomain != null) return _runtimeProfileDomain!;
    if (_cachedProfileDomain != null) return _cachedProfileDomain!;
    const explicit = String.fromEnvironment('PROFILE_DOMAIN');
    return _cleanDomain(explicit) ?? '';
  }

  /// Public profile link, e.g. `https://<canonical>/@handle`.
  static String profileUrl(String username) {
    final handle = username.trim().replaceFirst(RegExp(r'^@'), '');
    final domain = profileDomain;
    if (domain.isEmpty) return '';
    return 'https://$domain/@$handle';
  }

  /// Link-in-bio link, e.g. `https://<canonical>/l/handle`. Separate from the
  /// profile link: it opens the creator's bio page, not the profile.
  static String linkInBioUrl(String username) {
    final handle = username.trim().replaceFirst(RegExp(r'^@'), '');
    final domain = profileDomain;
    if (domain.isEmpty) return '';
    return 'https://$domain/l/$handle';
  }

  /// Builds a shareable, environment-aware deep link to a live stream.
  ///
  /// The stream id (the activity) and its host (the user) are packed into an
  /// opaque base64url token on the path, so the URL stays encoded instead of
  /// leaking raw identifiers and always targets the environment the app was
  /// built for (staging vs production).
  static String liveStreamUrl(
    int streamId, {
    int? hostUserId,
    String? trackingId,
  }) {
    final tracking = trackingId?.trim();
    if (tracking != null && tracking.isNotEmpty) {
      return absolute(DeepLinks.live(tracking));
    }
    if (streamId <= 0) {
      return absolute(DeepLinks.livePath);
    }
    return absolute(
      DeepLinks.live(
        DeepLinks.encodeLiveToken(streamId, hostUserId: hostUserId),
      ),
    );
  }

  /// Builds the shareable web URL for a canonical in-app [path].
  ///
  /// Always returns an `https://` Universal Link so the recipient lands in the
  /// app when it is installed and on the matching web page when it is not.
  static String absolute(String path) {
    final normalised = path.startsWith('/') ? path : '/$path';
    return '${webBaseUrl.replaceAll(RegExp(r'/+$'), '')}$normalised';
  }

  /// Whether the app targets a hosted (staging/production) backend.
  static bool get isLive =>
      apiEnv == 'production' ||
      apiEnv == 'prod' ||
      apiEnv == 'staging' ||
      _explicitBaseUrl.contains('https://');

  static String get apiBaseUrl {
    if (_explicitBaseUrl.isNotEmpty) return _explicitBaseUrl;

    switch (apiEnv) {
      case 'staging':
        return _stagingBaseUrl;
      case 'production':
      case 'prod':
        return _productionBaseUrl;
      case 'local':
      default:
        // Fallback to the local server for emulator/simulator.
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:8000/api/v1';
        }
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  static String get reverbHost {
    const explicit = String.fromEnvironment('REVERB_HOST');
    if (explicit.isNotEmpty) return explicit;
    if (_explicitBaseUrl.isNotEmpty) {
      final parsed = Uri.tryParse(_explicitBaseUrl);
      if (parsed != null && parsed.host.isNotEmpty) return parsed.host;
    }
    if (isLive) {
      return (apiEnv == 'production' || apiEnv == 'prod')
          ? 'api.murihspace.com'
          : 'api-staging.murihspace.com';
    }
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static int get reverbPort {
    const explicit = int.fromEnvironment('REVERB_PORT', defaultValue: 0);
    if (explicit != 0) return explicit;
    return isLive ? 443 : 8080;
  }

  static String get reverbScheme {
    const explicit = String.fromEnvironment('REVERB_SCHEME');
    if (explicit.isNotEmpty) return explicit;
    return isLive ? 'wss' : 'ws';
  }

  static String get reverbAppKey {
    const explicit = String.fromEnvironment('REVERB_APP_KEY');
    if (explicit.isNotEmpty) return explicit;
    return isLive ? 'rw7h5bb6otwudl0ch8xx' : 'murihspace';
  }

  static bool get isLocal => apiEnv == 'local' && _explicitBaseUrl.isEmpty;
}
