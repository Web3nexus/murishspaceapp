import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';

class AuthMethodConfig {
  final bool login;
  final bool registration;

  AuthMethodConfig({required this.login, required this.registration});

  factory AuthMethodConfig.fromJson(Map<String, dynamic> json) {
    return AuthMethodConfig(
      login: json['login'] ?? false,
      registration: json['registration'] ?? false,
    );
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
        
    final authMethods = innerData['auth_methods'] as Map<String, dynamic>? ?? innerData;
    
    final methodsData = authMethods['methods'] as Map<String, dynamic>? ?? {};
    final mappedMethods = <String, AuthMethodConfig>{};
    
    methodsData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        mappedMethods[key] = AuthMethodConfig.fromJson(value);
      }
    });

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
      state = PlatformState(
        isLoading: false,
        error: e.response?.data?['message'] ?? e.message ?? 'Failed to load platform config',
        config: state.config,
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
