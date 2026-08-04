import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// KYC status for the current user (Sprint 2 logic — KYC only when required).
class KycStatusInfo {
  final String status;
  final String? provider;
  final int? verificationId;
  final String? rejectionReason;
  final List<String> providers;
  final bool providerEnabled;

  const KycStatusInfo({
    required this.status,
    this.provider,
    this.verificationId,
    this.rejectionReason,
    this.providers = const [],
    this.providerEnabled = false,
  });

  factory KycStatusInfo.fromJson(Map<String, dynamic> json) {
    return KycStatusInfo(
      status: json['kyc_status'] as String? ?? 'not_required',
      provider: json['kyc_provider'] as String?,
      verificationId: (json['verification_id'] as num?)?.toInt(),
      rejectionReason: json['kyc_rejection_reason'] as String?,
      providers: (json['providers'] as List?)
          ?.whereType<String>()
          .toList() ??
          const [],
      providerEnabled: json['provider_enabled'] as bool? ?? false,
    );
  }

  bool get isVerified => status == 'verified' || status == 'approved';
  bool get isPending => status == 'pending' || status == 'in_review';
}

/// A dynamic condition/workflow currently requiring KYC for the user.
class KycTrigger {
  final String type;
  final String title;
  final String description;

  const KycTrigger({
    required this.type,
    required this.title,
    required this.description,
  });

  factory KycTrigger.fromJson(Map<String, dynamic> json) {
    return KycTrigger(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class KycState {
  final bool loading;
  final String? error;
  final KycStatusInfo? status;
  final List<KycTrigger> triggers;

  const KycState({
    this.loading = false,
    this.error,
    this.status,
    this.triggers = const [],
  });

  KycState copyWith({
    bool? loading,
    String? error,
    KycStatusInfo? status,
    List<KycTrigger>? triggers,
    bool clearError = false,
  }) {
    return KycState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      triggers: triggers ?? this.triggers,
    );
  }
}

class KycNotifier extends Notifier<KycState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  KycState build() {
    _load();
    return const KycState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _dio.get('/kyc/status'),
        _dio.get('/kyc/triggers'),
      ]);
      final api = ApiClient.instance;
      final statusPayload = api.unwrap(results[0]) as Map<String, dynamic>;
      final triggersRaw = api.unwrap(results[1]);
      final triggerList = <KycTrigger>[];
      if (triggersRaw is List) {
        for (final t in triggersRaw.whereType<Map<String, dynamic>>()) {
          triggerList.add(KycTrigger.fromJson(t));
        }
      } else if (triggersRaw is Map<String, dynamic>) {
        final inner = triggersRaw['triggers'];
        if (inner is List) {
          for (final t in inner.whereType<Map<String, dynamic>>()) {
            triggerList.add(KycTrigger.fromJson(t));
          }
        }
      }
      state = KycState(
        status: KycStatusInfo.fromJson(statusPayload),
        triggers: triggerList,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load KYC status.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  /// POST /kyc/start — begin a verification session for a provider.
  Future<Map<String, dynamic>?> start({String? provider}) async {
    try {
      final response = await _dio.post('/kyc/start', data: {
        'provider': ?provider,
      });
      final payload = ApiClient.instance.unwrap(response);
      return payload is Map<String, dynamic> ? payload : null;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return null;
    } catch (_) {
      state = state.copyWith(error: 'Could not start verification.');
      return null;
    }
  }

  /// POST /kyc/submit — manual document submission.
  Future<bool> submit({required Map<String, dynamic> payload}) async {
    try {
      await _dio.post('/kyc/submit', data: payload);
      await refresh();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Submission failed.');
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

final kycProvider = NotifierProvider<KycNotifier, KycState>(KycNotifier.new);
