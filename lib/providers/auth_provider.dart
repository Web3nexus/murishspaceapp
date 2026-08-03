import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/roles.dart';

/// Parsed user profile as returned by `/auth/*` and `/user`.
class UserProfile {
  final int id;
  final String name;
  final String email;
  final String username;
  final UserRole role;
  final String kycStatus;
  final bool emailVerified;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    required this.kycStatus,
    required this.emailVerified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: UserRole.fromApi(json['role'] as String? ?? 'member'),
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }
}

class AuthState {
  final UserProfile? user;
  final String? token;
  final bool loading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.token,
    this.loading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserProfile? user,
    String? token,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  AuthState build() {
    _tryAutoLogin();
    return const AuthState(loading: true);
  }

  Future<void> _tryAutoLogin() async {
    final token = await ApiClient.readToken();
    if (token == null) {
      state = const AuthState();
      return;
    }
    try {
      final response = await _dio.get('/user');
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      state = AuthState(user: UserProfile.fromJson(data), token: token);
    } catch (_) {
      await ApiClient.clearToken();
      state = const AuthState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final token = payload['token'] as String;
      final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      state = AuthState(user: user, token: token);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Login failed'));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String username,
    required String role,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'username': username,
        'role': role,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final token = payload['token'] as String;
      final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      state = AuthState(user: user, token: token);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Registration failed'));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return false;
    }
  }

  Future<void> logout() async {
    final token = state.token;
    if (token != null) {
      try {
        await _dio.post('/auth/logout');
      } catch (_) {
        // Best-effort: keep local logout working even if the API call fails.
      }
    }
    await ApiClient.clearToken();
    state = const AuthState();
  }

  /// Applies a locally-refreshed copy of the profile (e.g. after editing it).
  void setUser(UserProfile user) {
    state = state.copyWith(user: user);
  }

  String _dioError(DioException e, String fallback) {
    if (e.response?.data is Map<String, dynamic>) {
      final data = e.response?.data as Map<String, dynamic>;
      return data['message'] as String? ?? fallback;
    }
    return fallback;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
