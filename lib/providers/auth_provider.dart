import 'dart:convert';
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
  final String? avatarUrl;

  String? get avatar => avatarUrl;
  String? get coverImage => bannerUrl;
  final String? bio;
  final String? website;
  final String? category;
  final String? gender;
  final List<String> interests;
  final List<String> languages;
  final bool isCreatorAccount;
  final bool showInterests;
  final bool allowTagging;
  final bool showContactInfo;
  final String accountPrivacy;
  final String? phone;
  final DateTime? birthday;
  final String? country;
  final String? county;
  final String? state;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int communitiesCount;
  final int coins;
  final bool isOnline;
  final String? lastSeen;
  final DateTime? createdAt;
  final bool hasActiveVerificationBadge;

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
    this.avatarUrl,
    this.bio,
    this.website,
    this.category,
    this.gender,
    this.interests = const [],
    this.languages = const [],
    this.isCreatorAccount = true,
    this.showInterests = true,
    this.allowTagging = true,
    this.showContactInfo = true,
    this.accountPrivacy = 'public',
    this.phone,
    this.birthday,
    this.country,
    this.county,
    this.state,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.communitiesCount = 0,
    this.coins = 0,
    this.isOnline = true,
    this.lastSeen = 'online',
    this.createdAt,
    this.hasActiveVerificationBadge = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parsedBirthday;
    if (json['birthday'] != null) {
      parsedBirthday = DateTime.tryParse(json['birthday'].toString());
    }

    final rawInterests = json['interests'];
    final parsedInterests = rawInterests is List
        ? rawInterests.map((e) => e.toString()).toList()
        : <String>[];

    final rawLanguages = json['languages'];
    final parsedLanguages = rawLanguages is List
        ? rawLanguages.map((e) => e.toString()).toList()
        : <String>[];

    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: UserRole.fromApi(json['role'] as String? ?? 'member'),
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      emailVerified: json['email_verified'] as bool? ?? false,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? json['ai_onboarding_completed'] as bool? ?? false,
      bannerUrl: json['banner_url'] as String? ?? json['cover_image'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      bio: json['bio'] as String?,
      website: json['website'] as String?,
      category: json['category'] as String?,
      gender: json['gender'] as String?,
      interests: parsedInterests,
      languages: parsedLanguages,
      isCreatorAccount: json['is_creator_account'] as bool? ?? true,
      showInterests: json['show_interests'] as bool? ?? true,
      allowTagging: json['allow_tagging'] as bool? ?? true,
      showContactInfo: json['show_contact_info'] as bool? ?? true,
      accountPrivacy: json['account_privacy'] as String? ?? 'public',
      phone: json['mobile_number'] as String? ?? json['phone'] as String?,
      birthday: parsedBirthday,
      country: json['country'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? (json['followingCount'] as num?)?.toInt() ?? 0,
      communitiesCount: (json['communities_count'] as num?)?.toInt() ?? (json['communitiesCount'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? (json['coin_balance'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? true,
      lastSeen: json['last_seen'] as String? ?? json['lastSeen'] as String? ?? 'online',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      hasActiveVerificationBadge: json['has_active_verification_badge'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'role': role.apiValue,
      'kyc_status': kycStatus,
      'email_verified': emailVerified,
      'onboarding_completed': onboardingCompleted,
      'banner_url': bannerUrl,
      'avatar_url': avatarUrl,
      'bio': bio,
      'website': website,
      'category': category,
      'gender': gender,
      'interests': interests,
      'languages': languages,
      'is_creator_account': isCreatorAccount,
      'show_interests': showInterests,
      'allow_tagging': allowTagging,
      'show_contact_info': showContactInfo,
      'account_privacy': accountPrivacy,
      'mobile_number': phone,
      'phone': phone,
      'birthday': birthday?.toIso8601String().split('T').first,
      'country': country,
      'county': county,
      'state': state,
      'posts_count': postsCount,
      'followers_count': followersCount,
      'following_count': followingCount,
      'communities_count': communitiesCount,
      'coins': coins,
      'is_online': isOnline,
      'last_seen': lastSeen,
      'created_at': createdAt?.toIso8601String(),
      'has_active_verification_badge': hasActiveVerificationBadge,
    };
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
    String? avatarUrl,
    String? bio,
    String? website,
    String? category,
    String? gender,
    List<String>? interests,
    List<String>? languages,
    bool? isCreatorAccount,
    bool? showInterests,
    bool? allowTagging,
    bool? showContactInfo,
    String? accountPrivacy,
    String? phone,
    DateTime? birthday,
    String? country,
    String? county,
    String? state,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? communitiesCount,
    int? coins,
    bool? isOnline,
    String? lastSeen,
    DateTime? createdAt,
    bool? hasActiveVerificationBadge,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      category: category ?? this.category,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      isCreatorAccount: isCreatorAccount ?? this.isCreatorAccount,
      showInterests: showInterests ?? this.showInterests,
      allowTagging: allowTagging ?? this.allowTagging,
      showContactInfo: showContactInfo ?? this.showContactInfo,
      accountPrivacy: accountPrivacy ?? this.accountPrivacy,
      phone: phone ?? this.phone,
      birthday: birthday ?? this.birthday,
      country: country ?? this.country,
      county: county ?? this.county,
      state: state ?? this.state,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      communitiesCount: communitiesCount ?? this.communitiesCount,
      coins: coins ?? this.coins,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      hasActiveVerificationBadge: hasActiveVerificationBadge ?? this.hasActiveVerificationBadge,
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

/// google_sign_in 7 needs a single initialize() call before authenticate().
bool _googleSignInReady = false;

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

    UserProfile? cachedUser;
    try {
      final cachedStr = await ApiClient.readUserProfile();
      if (cachedStr != null && cachedStr.isNotEmpty) {
        cachedUser = UserProfile.fromJson(jsonDecode(cachedStr) as Map<String, dynamic>);
      }
    } catch (_) {}

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
      await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
      await _recordSavedAccount(token, user);
      state = AuthState(user: user, token: token);
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        // Token is rejected or expired on the backend: clear and send to login
        await _forgetCredentials(token);
        state = const AuthState();
        return;
      }
      // Offline fallback: restore cached user profile if available
      final user = cachedUser ?? UserProfile(
        id: 0,
        name: 'Murih Member',
        email: '',
        username: 'member',
        role: UserRole.member,
        kycStatus: 'pending',
        emailVerified: false,
        onboardingCompleted: true,
      );
      state = AuthState(user: user, token: token);
    }
  }

  Future<void> refreshProfile() async {
    final token = await ApiClient.readToken();
    if (token == null) return;
    try {
      final response = await _dio.get('/user');
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      var user = UserProfile.fromJson(data);
      final localOnboarded = await ApiClient.readAiOnboardingCompleted() == 'true';
      if (localOnboarded || user.onboardingCompleted) {
        user = user.copyWith(onboardingCompleted: true);
        if (!localOnboarded) {
          await ApiClient.saveAiOnboardingCompleted();
        }
      }
      await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
      await _recordSavedAccount(token, user);
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    final result = await loginWithDeviceCheck(email, password);
    return result['status'] == 'success';
  }

  Future<Map<String, dynamic>> loginWithDeviceCheck(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;

      if (payload['status'] == 'pending_device_approval') {
        state = state.copyWith(loading: false);
        return {
          'status': 'pending_device_approval',
          'pending_request': payload['pending_request'],
        };
      }

      final token = payload['token'] as String;
      final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
      await _recordSavedAccount(token, user);
      state = AuthState(user: user, token: token);
      return {'status': 'success', 'user': user};
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return {'status': 'error', 'message': e.message};
    } on DioException catch (e) {
      final msg = _dioError(e, 'Login failed');
      state = state.copyWith(loading: false, errorMessage: msg);
      return {'status': 'error', 'message': msg};
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return {'status': 'error', 'message': 'An error occurred'};
    }
  }

  Future<bool> completeApprovedLogin(String requestToken) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/auth/device-approval/check-status/$requestToken');
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;

      if (payload['status'] == 'approved') {
        final token = payload['token'] as String;
        final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
        await ApiClient.saveToken(token);
        await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
        await _recordSavedAccount(token, user);
        state = AuthState(user: user, token: token);
        return true;
      }
      state = state.copyWith(loading: false);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false);
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyDeviceLoginCode(String requestToken, String code) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/device-approval/verify-code', data: {
        'request_token': requestToken,
        'code': code,
      });
      final payload = ApiClient.instance.unwrap(response) as Map<String, dynamic>;

      if (payload['status'] == 'approved') {
        final token = payload['token'] as String;
        final user = UserProfile.fromJson(payload['user'] as Map<String, dynamic>);
        await ApiClient.saveToken(token);
        await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
        await _recordSavedAccount(token, user);
        state = AuthState(user: user, token: token);
        return {'status': 'success', 'user': user};
      }
      state = state.copyWith(loading: false);
      return {'status': 'error', 'message': payload['message'] ?? 'Verification failed'};
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return {'status': 'error', 'message': e.message};
    } on DioException catch (e) {
      final msg = _dioError(e, 'Verification failed');
      state = state.copyWith(loading: false, errorMessage: msg);
      return {'status': 'error', 'message': msg};
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'An error occurred');
      return {'status': 'error', 'message': 'An error occurred'};
    }
  }

  /// Switches into another account, logging in and storing it in saved accounts.
  Future<bool> switchAccount(String emailOrPhone, String password) async {
    return login(emailOrPhone, password);
  }

  /// Saves account metadata for quick multi-account switching.
  Future<void> _recordSavedAccount(String token, UserProfile user) async {
    try {
      final raw = await ApiClient.readSavedAccounts();
      List<Map<String, dynamic>> accounts = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          accounts = decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
      // Remove any existing entry for this user ID or token
      accounts.removeWhere((acc) => acc['id'] == user.id || acc['token'] == token);
      accounts.insert(0, {
        'id': user.id,
        'name': user.name,
        'username': user.username,
        'email': user.email,
        'phone': user.phone,
        'role': user.role.apiValue,
        'avatar_url': user.avatarUrl,
        'token': token,
      });
      if (accounts.length > 5) accounts = accounts.sublist(0, 5);
      await ApiClient.saveSavedAccounts(jsonEncode(accounts));
    } catch (_) {}
  }

  /// Retrieves list of saved accounts for fast switching.
  Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    try {
      final raw = await ApiClient.readSavedAccounts();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fast-switches active session to another saved account token.
  Future<bool> switchSavedAccount(String targetToken) async {
    state = state.copyWith(loading: true, clearError: true);
    await ApiClient.saveToken(targetToken);
    try {
      final response = await _dio.get('/user');
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final user = UserProfile.fromJson(data);
      await ApiClient.saveUserProfile(jsonEncode(user.toJson()));
      state = AuthState(user: user, token: targetToken);
      return true;
    } catch (e) {
      await refreshProfile();
      return state.user != null;
    }
  }

  Future<void> markOnboardingCompleted() async {
    await ApiClient.saveAiOnboardingCompleted();
    try {
      await _dio.post('/onboarding/complete');
    } catch (_) {}
    if (state.user != null) {
      final updated = state.user!.copyWith(onboardingCompleted: true);
      await ApiClient.saveUserProfile(jsonEncode(updated.toJson()));
      state = state.copyWith(user: updated);
    }
  }

  Future<Map<String, dynamic>?> requestOtp({
    required String intent,
    required String phoneE164,
    bool forceSms = false,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/otp/request', data: {
        'intent': intent,
        'phone_e164': phoneE164,
        if (forceSms) 'force_sms': true,
      });
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      state = state.copyWith(loading: false);
      return data;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return null;
    } on DioException catch (e) {
      // Non-production servers return debug_reason on OTP failures so a
      // misconfigured staging env (blank OTP_DRIVER, missing Twilio secrets) is
      // visible on the device instead of an unactionable "could not be sent".
      final base = _dioError(e, 'Failed to send code');
      final data = e.response?.data;
      // The server's response envelope nulls `data` on failures and relocates
      // unknown keys into `errors`, so debug_reason arrives under errors.
      final errors = data is Map<String, dynamic> ? data['errors'] : null;
      final reason = errors is Map<String, dynamic> ? errors['debug_reason'] : null;
      state = state.copyWith(
        loading: false,
        errorMessage: reason is String && reason.isNotEmpty ? '$base ($reason)' : base,
      );
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
    await _forgetCredentials(token);
    state = const AuthState();
  }

  /// Removes everything this device keeps for [token]: the active token, the
  /// cached profile, and that account's entry in the saved-accounts list.
  Future<void> _forgetCredentials(String? token) async {
    await ApiClient.clearToken();
    await ApiClient.clearUserProfile();
    if (token == null) return;
    try {
      final accounts = await getSavedAccounts();
      final remaining = accounts.where((acc) => acc['token'] != token).toList();
      if (remaining.length != accounts.length) {
        await ApiClient.saveSavedAccounts(jsonEncode(remaining));
      }
    } catch (_) {}
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
      await _forgetCredentials(state.token);
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
      const googleScopes = ['email', 'profile'];
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleSignInReady) {
        await googleSignIn.initialize();
        _googleSignInReady = true;
      }
      if (!googleSignIn.supportsAuthenticate()) {
        state = state.copyWith(
            loading: false, errorMessage: 'Google sign in is not supported on this device.');
        return false;
      }
      final GoogleSignInAccount account;
      try {
        account = await googleSignIn.authenticate(scopeHint: googleScopes);
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          state = state.copyWith(loading: false, errorMessage: 'Sign in cancelled');
          return false;
        }
        rethrow;
      }
      final idToken = account.authentication.idToken;
      final authz = await account.authorizationClient.authorizationForScopes(googleScopes) ??
          await account.authorizationClient.authorizeScopes(googleScopes);
      final accessToken = authz.accessToken;

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
    } on GoogleSignInException catch (e) {
      state = state.copyWith(loading: false, errorMessage: 'Google Sign in failed (${e.code.name}).');
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
    ApiClient.saveUserProfile(jsonEncode(user.toJson())).then<void>((_) {}, onError: (_) {});
  }

  /// Switches active profile mode (Member ↔ Creator ↔ Vendor).
  Future<bool> switchRole(UserRole targetRole) async {
    final u = state.user;
    if (u == null || u.role == targetRole) return u != null;
    state = state.copyWith(loading: true);
    try {
      await _dio.post('/profile/switch-role', data: {'role': targetRole.apiValue});
      final updatedUser = u.copyWith(role: targetRole);
      state = state.copyWith(user: updatedUser, loading: false);
      ApiClient.saveUserProfile(jsonEncode(updatedUser.toJson())).then<void>((_) {}, onError: (_) {});
      return true;
    } catch (_) {
      state = state.copyWith(loading: false);
      return false;
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

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
