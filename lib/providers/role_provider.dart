import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// A role transition application (Sprint 1 — account upgrade flow).
class RoleApplication {
  final int id;
  final String previousRole;
  final String requestedRole;
  final String status;
  final String? rejectionReason;
  final String? requestedAt;
  final String? approvedAt;

  const RoleApplication({
    required this.id,
    required this.previousRole,
    required this.requestedRole,
    required this.status,
    this.rejectionReason,
    this.requestedAt,
    this.approvedAt,
  });

  factory RoleApplication.fromJson(Map<String, dynamic> json) {
    return RoleApplication(
      id: (json['id'] as num?)?.toInt() ?? 0,
      previousRole: json['previous_role'] as String? ?? '',
      requestedRole: json['requested_role'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      requestedAt: json['requested_at'] as String?,
      approvedAt: json['approved_at'] as String?,
    );
  }
}

class RoleUpgradeState {
  final bool loading;
  final String? error;
  final RoleApplication? application;
  final List<RoleApplication> history;

  const RoleUpgradeState({
    this.loading = false,
    this.error,
    this.application,
    this.history = const [],
  });

  RoleUpgradeState copyWith({
    bool? loading,
    String? error,
    RoleApplication? application,
    List<RoleApplication>? history,
    bool clearError = false,
  }) {
    return RoleUpgradeState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      application: application ?? this.application,
      history: history ?? this.history,
    );
  }
}

class RoleUpgradeNotifier extends Notifier<RoleUpgradeState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  RoleUpgradeState build() {
    _load();
    return const RoleUpgradeState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _dio.get('/role/application'),
        _dio.get('/role/history'),
      ]);
      final api = ApiClient.instance;
      final appPayload = api.unwrap(results[0]);
      RoleApplication? application;
      if (appPayload is Map<String, dynamic>) {
        final raw = appPayload['application'];
        if (raw is Map<String, dynamic>) {
          application = RoleApplication.fromJson(raw);
        }
      }
      final historyPayload = api.unwrap(results[1]);
      List<RoleApplication> history = const [];
      if (historyPayload is Map<String, dynamic>) {
        final raw = historyPayload['history'];
        if (raw is List) {
          history = raw
              .whereType<Map<String, dynamic>>()
              .map(RoleApplication.fromJson)
              .toList();
        }
      } else if (historyPayload is List) {
        history = historyPayload
            .whereType<Map<String, dynamic>>()
            .map(RoleApplication.fromJson)
            .toList();
      }
      state = RoleUpgradeState(application: application, history: history);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load role applications.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// POST /role/apply — submit an upgrade request (creator | vendor | member).
  Future<bool> apply(String requestedRole) async {
    try {
      final response = await _dio.post('/role/apply', data: {
        'requested_role': requestedRole,
      });
      await _load();
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not submit application.');
      return false;
    }
  }

  /// DELETE /role/apply — cancel a pending application.
  Future<bool> cancel() async {
    try {
      await _dio.delete('/role/apply');
      await _load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Could not cancel application.');
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

final roleUpgradeProvider =
    NotifierProvider<RoleUpgradeNotifier, RoleUpgradeState>(RoleUpgradeNotifier.new);
