import 'dart:convert';
import 'dart:io' show Platform;

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
  static const String _productionWebUrl = 'https://murihspace.com';

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

  /// Generates the canonical profile URL for any user handle.
  static String profileUrl(String username) {
    final clean = username.trim().replaceFirst(RegExp(r'^@'), '');
    return '$webBaseUrl/u/$clean';
  }

  /// Generates the canonical link-in-bio URL.
  static String linkInBioUrl(String username) {
    final clean = username.trim().replaceFirst(RegExp(r'^@'), '');
    return '$webBaseUrl/l/$clean';
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
      return '$livePublicUrl/live/${Uri.encodeComponent(tracking)}';
    }
    if (streamId <= 0) {
      return '$livePublicUrl/live';
    }
    final payload = hostUserId != null && hostUserId > 0
        ? '$streamId:$hostUserId'
        : '$streamId';
    final token = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
    return '$livePublicUrl/live/$token';
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
