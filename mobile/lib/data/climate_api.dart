import 'package:dio/dio.dart';

import '../core/config.dart';
import 'auth_store.dart';
import 'climate_models.dart';

class ClimateApi {
  ClimateApi({Dio? dio, AuthStore? auth})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
              ),
            ),
        _auth = auth ?? AuthStore();

  final Dio _dio;
  final AuthStore _auth;

  Future<Options> _authOptions() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('not logged in');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Options?> _optionalAuth() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<ClimateAccountProfile> getAccountProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/climate/profile',
        options: await _authOptions(),
      );
      return ClimateAccountProfile.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw StateError('unauthorized');
      }
      rethrow;
    }
  }

  Future<ClimateAccountProfile> putAccountProfile(ClimateAccountProfile profile) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/climate/profile',
      data: profile.toJson(),
      options: await _authOptions(),
    );
    return ClimateAccountProfile.fromJson(response.data!);
  }

  Future<ClimateTodayResult> today({
    required String city,
    double? lat,
    double? lon,
    required ClimateProfilePayload profile,
    required String clientKey,
    String lang = 'ru',
    bool shade = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/climate/today',
      data: {
        'city': city,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'profile': profile.toJson(),
        'lang': lang,
        'shade': shade,
        'client_key': clientKey,
      },
    );
    return ClimateTodayResult.fromJson(response.data!);
  }

  Future<ClimateFeedbackResult> feedback({
    required String city,
    double? lat,
    double? lon,
    required int predictedSensation,
    required int actualSensation,
    required String wornTier,
    required String lookPreserved,
    required String moment,
    double? predictedUtciC,
    required String clientKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/climate/feedback',
      data: {
        'city': city,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'predicted_sensation': predictedSensation,
        'actual_sensation': actualSensation,
        'worn_tier': wornTier,
        'look_preserved': lookPreserved,
        'moment': moment,
        if (predictedUtciC != null) 'predicted_utci_c': predictedUtciC,
        'client_key': clientKey,
      },
      options: await _optionalAuth(),
    );
    return ClimateFeedbackResult.fromJson(response.data!);
  }

  Future<ClimatePlanResult> plan({
    required String text,
    required String city,
    double? lat,
    double? lon,
    required ClimateProfilePayload profile,
    required String clientKey,
    String lang = 'ru',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/climate/plan',
      data: {
        'text': text,
        'city': city,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'profile': profile.toJson(),
        'lang': lang,
        'client_key': clientKey,
      },
    );
    return ClimatePlanResult.fromJson(response.data!);
  }
}
