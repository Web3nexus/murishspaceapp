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
      message: data['message'] as String? ?? 'Request failed.',
      code: data['code'] as String?,
      errors: (data['errors'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      status: response.statusCode,
      requestId: data['request_id'] as String?,
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

  // ── Token storage ─────────────────────────────────────────────
  static Future<String?> readToken() => _secureStorage.read(key: tokenKey);
  static Future<void> saveToken(String token) => _secureStorage.write(key: tokenKey, value: token);
  static Future<void> clearToken() => _secureStorage.delete(key: tokenKey);

  // ── Helpers ───────────────────────────────────────────────────

  /// Short-lived UUID-ish idempotency key (no extra dependency).
  static String generateIdempotencyKey() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'mob-$micros-${DateTime.now().millisecondsSinceEpoch}';
  }
}
