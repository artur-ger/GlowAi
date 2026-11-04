import 'package:dio/dio.dart';

import '../core/config.dart';
import 'auth_store.dart';

class TripItem {
  TripItem({
    required this.id,
    required this.homeCity,
    required this.destCity,
    required this.status,
    required this.isActive,
    this.tripStart = '',
    this.tripEnd = '',
    this.latestCheckId,
    this.suggestedNext = '',
    this.homeLat,
    this.homeLon,
    this.destLat,
    this.destLon,
  });

  final int id;
  final String homeCity;
  final String destCity;
  final String status;
  final bool isActive;
  final String tripStart;
  final String tripEnd;
  final int? latestCheckId;
  final String suggestedNext;
  final double? homeLat;
  final double? homeLon;
  final double? destLat;
  final double? destLon;

  String get statusLabel => switch (status) {
        'on_site' => 'На месте',
        'return_home' => 'Возврат',
        'done' => 'Закрыта',
        _ => 'До поездки',
      };

  factory TripItem.fromJson(Map<String, dynamic> json) => TripItem(
        id: (json['id'] as num).toInt(),
        homeCity: json['home_city'] as String? ?? '',
        destCity: json['dest_city'] as String? ?? '',
        status: json['status'] as String? ?? 'pre_trip',
        isActive: json['is_active'] as bool? ?? false,
        tripStart: json['trip_start'] as String? ?? '',
        tripEnd: json['trip_end'] as String? ?? '',
        latestCheckId: (json['latest_check_id'] as num?)?.toInt(),
        suggestedNext: json['suggested_next'] as String? ?? '',
        homeLat: (json['home_lat'] as num?)?.toDouble(),
        homeLon: (json['home_lon'] as num?)?.toDouble(),
        destLat: (json['dest_lat'] as num?)?.toDouble(),
        destLon: (json['dest_lon'] as num?)?.toDouble(),
      );
}

class DailyTip {
  DailyTip({
    required this.city,
    required this.tip,
    this.tempC,
    this.humidity,
    this.uv,
    this.tripId,
  });

  final String city;
  final String tip;
  final double? tempC;
  final double? humidity;
  final double? uv;
  final int? tripId;

  factory DailyTip.fromJson(Map<String, dynamic> json) => DailyTip(
        city: json['city'] as String? ?? '',
        tip: json['tip'] as String? ?? '',
        tempC: (json['temp_c'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
        uv: (json['uv'] as num?)?.toDouble(),
        tripId: (json['trip_id'] as num?)?.toInt(),
      );
}

class TripsApi {
  TripsApi({Dio? dio, AuthStore? store})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
              ),
            ),
        _store = store ?? AuthStore();

  final Dio _dio;
  final AuthStore _store;

  Future<Options> _auth() async {
    final token = await _store.getToken();
    if (token == null || token.isEmpty) throw StateError('login required');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<TripItem?> activeTrip() async {
    final response = await _dio.get<dynamic>(
      '/api/v1/trips/active',
      options: await _auth(),
    );
    if (response.data == null) return null;
    return TripItem.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<TripItem> setStatus(int tripId, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/trips/$tripId/status',
      data: {'status': status},
      options: await _auth(),
    );
    return TripItem.fromJson(response.data!);
  }

  Future<DailyTip> dailyTip(int tripId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/trips/$tripId/daily-tip',
      options: await _auth(),
    );
    return DailyTip.fromJson(response.data!);
  }
}
