import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
const _secureStorage = FlutterSecureStorage();

/// A typed API error carrying the backend envelope fields.
class ApiException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? errors;
  final int? status;
  final String? requestId;

  ApiException({
    required this.message,
    this.code,
    this.errors,
    this.status,
    this.requestId,
  });

  @override
  String toString() => message;
}

/// Shared HTTP client for the whole app.
///
/// - Injects the bearer token on every request.
/// - Unwraps the backend envelope (`{success, data, message, errors}`).
/// - Normalises failures into [ApiException].
class ApiClient {
  static const String tokenKey = 'murihspace_token';

  final Dio dio;

  ApiClient._(this.dio);

  static final ApiClient instance = ApiClient._(_createDio());

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

    return dio;
  }

  /// Returns the unwrapped payload from a successful response.
  /// Throws [ApiException] for API/network failures.
  dynamic unwrap(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) return data;
    final isSuccess = data['success'] as bool? ?? (data.containsKey('data'));
    if (isSuccess) return data['data'];
    throw ApiException(
      message: data['message']?.toString() ?? 'Request failed.',
      code: data['code']?.toString(),
      errors: (data['errors'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      status: response.statusCode,
      requestId: data['request_id']?.toString(),
    );
  }

  /// Unwraps a list payload, tolerating plain arrays and paginated shapes.
  List<T> unwrapList<T>(Response<dynamic> response, T Function(Map<String, dynamic>) fromJson) {
    final payload = unwrap(response);
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList();
      }
    }
    return [];
  }

  // ── Token & Onboarding storage ────────────────────────────────
  static const aiOnboardingCompletedKey = 'murihspace_ai_onboarding_completed';
  static const userProfileKey = 'murihspace_user_profile';
  static const savedAccountsKey = 'murihspace_saved_accounts';

  static Future<String?> readToken() => _secureStorage.read(key: tokenKey);
  static Future<void> saveToken(String token) => _secureStorage.write(key: tokenKey, value: token);
  static Future<void> clearToken() => _secureStorage.delete(key: tokenKey);

  static Future<String?> readUserProfile() => _secureStorage.read(key: userProfileKey);
  static Future<void> saveUserProfile(String userJson) => _secureStorage.write(key: userProfileKey, value: userJson);
  static Future<void> clearUserProfile() => _secureStorage.delete(key: userProfileKey);

  static Future<String?> readSavedAccounts() => _secureStorage.read(key: savedAccountsKey);
  static Future<void> saveSavedAccounts(String accountsJson) => _secureStorage.write(key: savedAccountsKey, value: accountsJson);

  static Future<String?> readAiOnboardingCompleted() => _secureStorage.read(key: aiOnboardingCompletedKey);
  static Future<void> saveAiOnboardingCompleted() => _secureStorage.write(key: aiOnboardingCompletedKey, value: 'true');
  static Future<void> clearAiOnboardingCompleted() => _secureStorage.delete(key: aiOnboardingCompletedKey);


  // ── Helpers ───────────────────────────────────────────────────

  /// Short-lived UUID-ish idempotency key (no extra dependency).
  static String generateIdempotencyKey() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'mob-$micros-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Authorizes a Reverb private channel via `POST /broadcasting/auth`.
  ///
  /// The route lives at the app origin (outside `/api/v1`), so the origin is
  /// derived from [Env.apiBaseUrl] and the call is signed with the stored token.
  static Future<String?> broadcastAuth({
    required String socketId,
    required String channelName,
  }) async {
    final base = Env.apiBaseUrl;
    final origin = base.endsWith('/api/v1')
        ? base.substring(0, base.length - '/api/v1'.length)
        : base;
    final token = await readToken();
    final dio = Dio(BaseOptions(
      baseUrl: origin,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));
    try {
      final response = await dio.post('/broadcasting/auth', data: {
        'socket_id': socketId,
        'channel_name': channelName,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data['auth'] as String?;
    } catch (_) {
      // Authorization failures are non-fatal: the UI keeps working via REST.
    }
    return null;
  }
}
