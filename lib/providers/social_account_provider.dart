import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// A connected social profile (Sprint 5 — social account intelligence).
class SocialAccount {
  final int id;
  final String provider;
  final String? providerUserId;
  final String? username;
  final String? profileUrl;
  final int followerCount;
  final int followingCount;
  final bool verifiedOnProvider;
  final String? syncStatus;

  const SocialAccount({
    required this.id,
    required this.provider,
    this.providerUserId,
    this.username,
    this.profileUrl,
    required this.followerCount,
    required this.followingCount,
    required this.verifiedOnProvider,
    this.syncStatus,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? '',
      providerUserId: json['provider_user_id'] as String?,
      username: json['username'] as String?,
      profileUrl: json['profile_url'] as String?,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      verifiedOnProvider: json['verified_on_provider'] as bool? ?? false,
      syncStatus: json['sync_status'] as String?,
    );
  }
}

/// Combined verified follower summary (server-computed).
class FollowerSummary {
  final int combinedFollowers;
  final Map<String, int> providerBreakdown;
  final int? thresholdAtTime;

  const FollowerSummary({
    required this.combinedFollowers,
    this.providerBreakdown = const {},
    this.thresholdAtTime,
  });

  factory FollowerSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = <String, int>{};
    final rawBreakdown = json['provider_breakdown'];
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((key, value) {
        if (key is String && value is num) breakdown[key] = value.toInt();
      });
    }
    return FollowerSummary(
      combinedFollowers: (json['combined_followers'] as num?)?.toInt() ?? 0,
      providerBreakdown: breakdown,
      thresholdAtTime: (json['threshold_at_time'] as num?)?.toInt(),
    );
  }
}

class SocialAccountState {
  final bool loading;
  final String? error;
  final List<SocialAccount> accounts;
  final FollowerSummary? summary;

  const SocialAccountState({
    this.loading = false,
    this.error,
    this.accounts = const [],
    this.summary,
  });

  SocialAccountState copyWith({
    bool? loading,
    String? error,
    List<SocialAccount>? accounts,
    FollowerSummary? summary,
    bool clearError = false,
  }) {
    return SocialAccountState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      accounts: accounts ?? this.accounts,
      summary: summary ?? this.summary,
    );
  }
}

class SocialAccountNotifier extends Notifier<SocialAccountState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  SocialAccountState build() {
    _load();
    return const SocialAccountState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _dio.get('/social-accounts'),
        _dio.get('/social-accounts/follower-summary'),
      ]);
      final api = ApiClient.instance;
      final accounts = api.unwrapList<SocialAccount>(results[0], SocialAccount.fromJson);
      FollowerSummary? summary;
      final summaryPayload = api.unwrap(results[1]);
      if (summaryPayload is Map<String, dynamic>) {
        summary = FollowerSummary.fromJson(summaryPayload);
      }
      state = SocialAccountState(accounts: accounts, summary: summary);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load social accounts.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// POST /social-accounts/manual — add a manually-entered profile.
  Future<bool> addManual({
    required String provider,
    required String username,
    int followerCount = 0,
  }) async {
    try {
      await _dio.post('/social-accounts/manual', data: {
        'provider': provider,
        'username': username,
        'follower_count': followerCount,
      });
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not add the account.');
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await _dio.delete('/social-accounts/$id');
      state = state.copyWith(
        accounts: state.accounts.where((a) => a.id != id).toList(),
        clearError: true,
      );
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not remove the account.');
      return false;
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? 'Request failed.';
    }
    return 'Request failed.';
  }
}

final socialAccountProvider =
    NotifierProvider<SocialAccountNotifier, SocialAccountState>(SocialAccountNotifier.new);
