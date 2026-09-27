import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';

class AuthMethodConfig {
  final bool login;
  final bool registration;

  AuthMethodConfig({required this.login, required this.registration});

  /// Both flags must be present and genuinely boolean.
  ///
  /// Coercing a missing or wrongly-typed flag to `false` would silently switch
  /// off a sign-in method the admin left enabled, so a malformed entry is
  /// rejected outright and the caller drops it instead.
  factory AuthMethodConfig.fromJson(Map<String, dynamic> json) {
    final login = json['login'];
    final registration = json['registration'];

    if (login is! bool || registration is! bool) {
      throw const FormatException(
        'Auth method flags must be explicit booleans.',
      );
    }

    return AuthMethodConfig(login: login, registration: registration);
  }
}

class PlatformConfig {
  final String primaryMethod;
  final Map<String, AuthMethodConfig> methods;
  final bool kycEnabled;
  final String kycProvider;

  PlatformConfig({
    required this.primaryMethod,
    required this.methods,
    this.kycEnabled = true,
    this.kycProvider = 'didit',
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    // Handling case where data is nested in 'data' from /platform or just plain
    // Some backends mistakenly double-wrap the response: {"success": true, "data": {"data": {...}}}
    // which ApiClient unwraps to {"data": {"auth_methods": ...}}.
    final innerData = json.containsKey('data') && json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;

    final authMethodsRaw = innerData['auth_methods'];
    if (authMethodsRaw is! Map<String, dynamic>) {
      throw const FormatException(
        'Platform config has no auth_methods map.',
      );
    }

    final authMethods = authMethodsRaw;
    final methodsData = authMethods['methods'];

    final mappedMethods = <String, AuthMethodConfig>{};
    final malformed = <String>[];

    if (methodsData is Map<String, dynamic>) {
      methodsData.forEach((key, value) {
        if (value is! Map<String, dynamic>) {
          malformed.add('$key (not an object)');

          return;
        }
        try {
          // A well-formed {false, false} entry is kept: it is a method the admin
          // deliberately switched off.
          mappedMethods[key] = AuthMethodConfig.fromJson(value);
        } on FormatException {
          malformed.add(key);
        }
      });
    }

    // Any malformed entry invalidates the whole map rather than being skipped.
    // Silently dropping one can leave every remaining method disabled, which
    // reads to the UI as "no sign-in options" and locks the user out. Failing
    // open (config treated as unavailable) keeps the resilient defaults visible.
    if (malformed.isNotEmpty) {
      throw FormatException(
        'Platform config returned malformed auth methods: ${malformed.join(', ')}.',
      );
    }

    // An empty method map would make every isLoginEnabled() lookup return
    // false, hiding all sign-in options and locking the user out. Treat it as
    // "config unavailable" so callers fall back to their defaults instead.
    if (mappedMethods.isEmpty) {
      throw const FormatException(
        'Platform config returned no usable auth methods.',
      );
    }

    return PlatformConfig(
      primaryMethod: authMethods['primary'] ?? 'phone_otp',
      methods: mappedMethods,
      kycEnabled: innerData['kyc_enabled'] ?? true,
      kycProvider: innerData['kyc_provider'] ?? 'didit',
    );
  }

  bool isLoginEnabled(String method) => methods[method]?.login ?? false;
  bool isRegistrationEnabled(String method) => methods[method]?.registration ?? false;
}

class PlatformState {
  final bool isLoading;
  final PlatformConfig? config;
  final String? error;

  PlatformState({this.isLoading = false, this.config, this.error});
}

class PlatformNotifier extends Notifier<PlatformState> {
  @override
  PlatformState build() {
    // Start fetching config asynchronously when the provider is built.
    Future.microtask(() => fetchConfig());
    return PlatformState();
  }

  Future<void> fetchConfig() async {
    state = PlatformState(isLoading: true, config: state.config);
    try {
      final response = await ApiClient.instance.dio.get('/platform');
      final data = ApiClient.instance.unwrap(response);
      state = PlatformState(
        isLoading: false,
        config: PlatformConfig.fromJson(data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      // Network/transport failure: the last known-good config is still the best
      // available answer, so keep it and surface the error.
      state = PlatformState(
        isLoading: false,
        error: e.response?.data?['message'] ?? e.message ?? 'Failed to load platform config',
        config: state.config,
      );
    } on FormatException catch (e) {
      // The payload arrived but is unusable (e.g. an admin toggled a method and
      // the config no longer parses). Keeping the stale config would keep
      // advertising the previous method set — the exact "disabled method still
      // shows" symptom — so drop it and let the screens fall back to defaults.
      state = PlatformState(
        isLoading: false,
        error: e.message,
        config: null,
      );
    } catch (e) {
      state = PlatformState(
        isLoading: false,
        error: e.toString(),
        config: state.config,
      );
    }
  }
}

final platformProvider = NotifierProvider<PlatformNotifier, PlatformState>(() {
  return PlatformNotifier();
});
