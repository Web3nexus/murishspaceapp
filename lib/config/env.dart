import 'dart:io' show Platform;

/// Resolves which API backend (and Reverb cluster) the app talks to.
///
/// Resolution order:
///  1. `--dart-define=API_BASE_URL=...` — explicit override (LAN IP,
///     tunnel, anything). Highest priority, always wins.
///  2. `--dart-define=API_ENV=production|staging` — a named environment
///     mapped to a hosted URL. Defaults to `local`.
///  3. Local fallback based on the running platform so emulators and
///     simulators "just work" against a local `php artisan serve`:
///       - Android emulator -> http://10.0.2.2:8000/api/v1
///       - everything else   -> http://127.0.0.1:8000/api/v1
///
/// Real devices cannot reach the dev machine via 10.0.2.2/127.0.0.1, so
/// for a phone use an explicit override:
///   `flutter run --dart-define=API_BASE_URL=http://<your-mac-lan-ip>:8000/api/v1`
/// or point at a hosted backend:
///   `flutter run --dart-define=API_ENV=staging`
class Env {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'MurihSpace',
  );

  static const String _explicitBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String apiEnv = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'local',
  );

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

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
  defaultValue: 8080,
  );

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