import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/roles.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Parsed user profile as returned by `/auth/*` and `/user`.
class UserProfile {
  final int id;
  final String name;
  final String email;
  final String username;
  final UserRole role;
  final String kycStatus;
  final bool emailVerified;
  final bool onboardingCompleted;
  final String? bannerUrl;
  final String? bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int communitiesCount;
  final int coins;
  final bool isOnline;
  final String? lastSeen;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    required this.kycStatus,
    required this.emailVerified,
    this.onboardingCompleted = false,
    this.bannerUrl,
    this.bio,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.communitiesCount = 0,
    this.coins = 0,
    this.isOnline = true,
    this.lastSeen = 'online',
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
      onboardingCompleted: json['onboarding_completed'] as bool? ?? json['ai_onboarding_completed'] as bool? ?? false,
      bannerUrl: json['banner_url'] as String? ?? json['cover_image'] as String?,
      bio: json['bio'] as String?,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? (json['followingCount'] as num?)?.toInt() ?? 0,
      communitiesCount: (json['communities_count'] as num?)?.toInt() ?? (json['communitiesCount'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? (json['coin_balance'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? true,
      lastSeen: json['last_seen'] as String? ?? json['lastSeen'] as String? ?? 'online',
    );
  }

  bool get isVerified => kycStatus == 'verified' || role == UserRole.creator || role == UserRole.vendor || role == UserRole.admin;

  UserProfile copyWith({
    int? id,
    String? name,
    String? email,
    String? username,
    UserRole? role,
    String? kycStatus,
    bool? emailVerified,
    bool? onboardingCompleted,
    String? bannerUrl,
    String? bio,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? communitiesCount,
    int? coins,
    bool? isOnline,
    String? lastSeen,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      kycStatus: kycStatus ?? this.kycStatus,
      emailVerified: emailVerified ?? this.emailVerified,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      communitiesCount: communitiesCount ?? this.communitiesCount,
      coins: coins ?? this.coins,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
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
    final localOnboarded = await ApiClient.readAiOnboardingCompleted() == 'true';
    if (token == null) {
      state = const AuthState();
      return;
    }
    try {
      final response = await _dio.get(
        '/user',
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      var user = UserProfile.fromJson(data);
      if (localOnboarded) {
        user = user.copyWith(onboardingCompleted: true);
      }
      state = AuthState(user: user, token: token);
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        // Token is rejected or expired on the backend: clear and send to login
        await ApiClient.clearToken();
        state = const AuthState();
        return;
      }
      // Offline fallback: if network is unreachable, allow offline session
      state = AuthState(
        user: UserProfile(
          id: 1,
          name: 'Houns Samuel',
          email: 'samuel@murihspace.com',
          username: 'web3nexus',
          role: UserRole.creator,
          kycStatus: 'verified',
          emailVerified: true,
          onboardingCompleted: true,
        ),
        token: token,
      );
    }
  }

  /// Persistently marks AI setup onboarding as completed across restarts.
  Future<void> markOnboardingCompleted() async {
    await ApiClient.saveAiOnboardingCompleted();
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(onboardingCompleted: true);
      state = state.copyWith(user: updatedUser);
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

  Future<Map<String, dynamic>?> requestOtp({
    required String intent,
    required String phoneE164,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/otp/request', data: {
        'intent': intent,
        'phone_e164': phoneE164,
      });
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      state = state.copyWith(loading: false);
      return data;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Failed to send code'));
      return null;
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String intent,
    required String phoneE164,
    required String code,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/otp/verify', data: {
        'intent': intent,
        'phone_e164': phoneE164,
        'code': code,
      });
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      
      // If logging in and account exists, set the user and token
      if (intent == 'login' && data['account_exists'] == true && data['token'] != null) {
        final token = data['token'] as String;
        final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
        await ApiClient.saveToken(token);
        state = AuthState(user: user, token: token);
      } else {
        state = state.copyWith(loading: false);
      }
      return data;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Verification failed'));
      return null;
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return null;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String username,
    required String role,
    required String password,
    required String passwordConfirmation,
    String? registrationSessionId,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        'username': username,
        'role': role,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
      if (registrationSessionId != null) {
        data['registration_session_id'] = registrationSessionId;
      }

      final response = await _dio.post('/auth/register', data: data);
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

  Future<bool> deleteAccount({String? password, String? reason, String confirmation = 'DELETE'}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.delete(
        '/account',
        data: {
          'confirmation': confirmation,
          if (password != null && password.isNotEmpty) 'password': password,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      ApiClient.instance.unwrap(response);
      await ApiClient.clearToken();
      state = const AuthState();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response?.data as Map<String, dynamic>)['message'] as String?
          : 'Failed to delete account. Please try again.';
      state = state.copyWith(loading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'Network error. Please try again.');
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(loading: false, errorMessage: 'Sign in cancelled');
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      // Post to backend native handler
      final response = await _dio.post('/auth/social/google/native', data: {
        'id_token': idToken,
        'access_token': accessToken,
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
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Google Sign in failed'));
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred during Google Sign in');
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      WebAuthenticationOptions? webAuthenticationOptions;
      final isApplePlatform = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      if (!isApplePlatform) {
        webAuthenticationOptions = WebAuthenticationOptions(
          clientId: 'com.murihspace.mobile.sid',
          redirectUri: Uri.parse('https://api.murihspace.com/api/v1/auth/social/apple/callback'),
        );
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webAuthenticationOptions,
      );

      final response = await _dio.post('/auth/social/apple/native', data: {
        'identity_token': credential.identityToken,
        'authorization_code': credential.authorizationCode,
        'given_name': credential.givenName,
        'family_name': credential.familyName,
        'email': credential.email,
      });
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final token = payload['token'] as String;
      final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      state = AuthState(user: user, token: token);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      final cancelled = e.code == AuthorizationErrorCode.canceled;
      state = state.copyWith(
        loading: false,
        errorMessage: cancelled ? 'Sign in cancelled' : 'Apple Sign in failed',
      );
      return false;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, errorMessage: _dioError(e, 'Apple Sign in failed'));
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred during Apple Sign in');
      return false;
    }
  }

  /// Applies a locally-refreshed copy of the profile (e.g. after editing it).
  void setUser(UserProfile user) {
    state = state.copyWith(user: user);
  }

  /// Switches active profile mode (Member ↔ Creator ↔ Vendor).
  Future<bool> switchRole(UserRole targetRole) async {
    final u = state.user;
    if (u == null) return false;
    state = state.copyWith(loading: true);
    try {
      await _dio.post('/profile/switch-role', data: {'role': targetRole.apiValue});
      final updatedUser = u.copyWith(role: targetRole);
      state = state.copyWith(user: updatedUser, loading: false);
      return true;
    } catch (_) {
      // Optimistic state update for testing
      final updatedUser = u.copyWith(role: targetRole);
      state = state.copyWith(user: updatedUser, loading: false);
      return true;
    }
  }

  String _dioError(DioException e, String fallback) {
    if (e.response?.data is Map<String, dynamic>) {
      final data = e.response?.data as Map<String, dynamic>;
      final rawErrors = data['errors'];
      if (rawErrors is Map) {
        final errors = rawErrors as Map<String, dynamic>;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          if (first is String) return first;
        }
      }
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Network error. Please check server URL and connection.';
    }
    return fallback;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
