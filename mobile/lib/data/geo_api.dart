import 'package:dio/dio.dart';

import '../core/config.dart';
import 'places.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.results,
    this.suggestions = const [],
  });

  final List<PlaceOption> results;
  final List<PlaceOption> suggestions;
}

class GeoApi {
  GeoApi({Dio? dio, Dio? publicDio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ),
        _publicDio = publicDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;
  final Dio _publicDio;

  /// Любой город мира: сначала backend-прокси (Open-Meteo + транслит), при сбое — напрямую.
  Future<PlaceSearchResult> searchPlaces({
    required String query,
    String? countryCode,
  }) async {
    try {
      return await _searchBackend(query: query, countryCode: countryCode);
    } catch (_) {
      final results = await _searchOpenMeteo(query: query, countryCode: countryCode);
      return PlaceSearchResult(results: results);
    }
  }

  Future<List<PlaceOption>> popularPlaces({required String countryCode}) async {
    if (countryCode.isEmpty) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/geo/popular',
        queryParameters: {
          'country_code': countryCode.toUpperCase(),
          'limit': 12,
        },
      );
      final results = (response.data?['results'] as List?) ?? [];
      return results
          .whereType<Map>()
          .map((e) => PlaceOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<PlaceSearchResult> _searchBackend({
    required String query,
    String? countryCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/geo/places',
      queryParameters: {
        'q': query,
        if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode,
        'limit': 15,
      },
    );
    final results = (response.data?['results'] as List?) ?? [];
    final suggestions = (response.data?['suggestions'] as List?) ?? [];
    return PlaceSearchResult(
      results: results
          .whereType<Map>()
          .map((e) => PlaceOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      suggestions: suggestions
          .whereType<Map>()
          .map((e) => PlaceOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<List<PlaceOption>> _searchOpenMeteo({
    required String query,
    String? countryCode,
  }) async {
    final response = await _publicDio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': query,
        'count': 15,
        'language': 'ru',
        'format': 'json',
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode.toUpperCase(),
      },
    );
    final results = (response.data?['results'] as List?) ?? [];
    return results.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final name = '${item['name'] ?? ''}';
      final country = '${item['country'] ?? ''}';
      final code = '${item['country_code'] ?? ''}'.toUpperCase();
      final admin1 = item['admin1']?.toString();
      final parts = <String>[
        name,
        if (admin1 != null && admin1.isNotEmpty) admin1,
        if (country.isNotEmpty) country,
      ];
      return PlaceOption(
        name: name,
        country: country.isEmpty ? code : country,
        countryCode: code,
        admin1: admin1,
        latitude: (item['latitude'] as num?)?.toDouble(),
        longitude: (item['longitude'] as num?)?.toDouble(),
        label: parts.join(', '),
      );
    }).toList();
  }
}
