import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// Country record (Sprint 3 — country intelligence).
class Country {
  final String iso2;
  final String iso3;
  final String name;
  final String callingCode;
  final String? flag;
  final String currency;
  final bool stateRequired;
  final bool postalCodeRequired;

  const Country({
    required this.iso2,
    required this.iso3,
    required this.name,
    required this.callingCode,
    this.flag,
    required this.currency,
    required this.stateRequired,
    required this.postalCodeRequired,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      iso2: json['iso2'] as String? ?? '',
      iso3: json['iso3'] as String? ?? '',
      name: json['name'] as String? ?? '',
      callingCode: json['calling_code'] as String? ?? '',
      flag: json['flag'] as String?,
      currency: json['currency'] as String? ?? 'NGN',
      stateRequired: json['state_required'] as bool? ?? false,
      postalCodeRequired: json['postal_code_required'] as bool? ?? false,
    );
  }
}

/// State/province/region belonging to a country.
class Region {
  final int id;
  final String countryIso2;
  final String code;
  final String name;

  const Region({
    required this.id,
    required this.countryIso2,
    required this.code,
    required this.name,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: (json['id'] as num?)?.toInt() ?? 0,
      countryIso2: json['country_iso2'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class CountryState {
  final bool loading;
  final String? error;
  final List<Country> countries;
  final List<Region> regions;
  final String? selectedIso2;

  const CountryState({
    this.loading = false,
    this.error,
    this.countries = const [],
    this.regions = const [],
    this.selectedIso2,
  });

  CountryState copyWith({
    bool? loading,
    String? error,
    List<Country>? countries,
    List<Region>? regions,
    String? selectedIso2,
    bool clearError = false,
  }) {
    return CountryState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      countries: countries ?? this.countries,
      regions: regions ?? this.regions,
      selectedIso2: selectedIso2 ?? this.selectedIso2,
    );
  }
}

class CountryNotifier extends Notifier<CountryState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  CountryState build() {
    _loadCountries();
    return const CountryState(loading: true);
  }

  Future<void> _loadCountries() async {
    try {
      final response = await _dio.get('/countries');
      final list = ApiClient.instance.unwrapList<Country>(response, Country.fromJson);
      state = CountryState(countries: list);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load countries.');
    }
  }

  Future<void> refresh() => _loadCountries();

  /// GET /countries/{iso2}/states — load regions for the selected country.
  Future<void> selectCountry(String iso2) async {
    state = state.copyWith(selectedIso2: iso2, regions: const [], clearError: true);
    try {
      final response = await _dio.get('/countries/$iso2/states');
      final payload = ApiClient.instance.unwrap(response);
      final raw = payload is Map<String, dynamic> ? payload['data'] : payload;
      final regions = raw is List
          ? raw.whereType<Map<String, dynamic>>().map(Region.fromJson).toList()
          : <Region>[];
      state = state.copyWith(regions: regions);
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(error: 'Failed to load regions.');
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

final countryProvider = NotifierProvider<CountryNotifier, CountryState>(CountryNotifier.new);
