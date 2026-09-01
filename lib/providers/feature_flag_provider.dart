import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// Model representing a platform feature flag.
class FeatureFlagModel {
  final int id;
  final String key;
  final String label;
  final String? description;
  final bool enabled;

  FeatureFlagModel({
    required this.id,
    required this.key,
    required this.label,
    this.description,
    required this.enabled,
  });

  factory FeatureFlagModel.fromJson(Map<String, dynamic> json) {
    return FeatureFlagModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'label': label,
        'description': description,
        'enabled': enabled,
      };
}

/// State container for feature flags.
class FeatureFlagState {
  final Map<String, bool> flags;
  final bool loading;
  final String? error;

  const FeatureFlagState({
    this.flags = const {},
    this.loading = false,
    this.error,
  });

  FeatureFlagState copyWith({
    Map<String, bool>? flags,
    bool? loading,
    String? error,
  }) {
    return FeatureFlagState(
      flags: flags ?? this.flags,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  bool isEnabled(String key, {bool defaultValue = true}) {
    if (!flags.containsKey(key)) return defaultValue;
    return flags[key] ?? defaultValue;
  }
}

/// Notifier that fetches and manages Feature Flags state in mobile client.
class FeatureFlagNotifier extends Notifier<FeatureFlagState> {
  final _dio = ApiClient.instance.dio;

  @override
  FeatureFlagState build() {
    fetchFlags();
    return const FeatureFlagState(loading: true);
  }

  Future<void> fetchFlags() async {
    state = state.copyWith(loading: true);
    try {
      final response = await _dio.get('/feature-flags');
      final dataList = (response.data['data'] as List? ?? []);
      final Map<String, bool> parsedFlags = {};

      for (final item in dataList) {
        if (item is Map<String, dynamic>) {
          final key = item['key'] as String?;
          final enabled = item['enabled'] as bool? ?? true;
          if (key != null && key.isNotEmpty) {
            parsedFlags[key] = enabled;
          }
        }
      }

      state = state.copyWith(flags: parsedFlags, loading: false);
    } catch (_) {
      // Fallback to default enabled state on offline/network errors
      state = state.copyWith(loading: false, error: 'Could not refresh feature flags.');
    }
  }

  bool isEnabled(String key, {bool defaultValue = true}) {
    return state.isEnabled(key, defaultValue: defaultValue);
  }
}

/// Riverpod Provider for Feature Flags state.
final featureFlagProvider =
    NotifierProvider<FeatureFlagNotifier, FeatureFlagState>(FeatureFlagNotifier.new);
