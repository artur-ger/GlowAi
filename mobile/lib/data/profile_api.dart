import 'package:dio/dio.dart';

import '../core/config.dart';
import 'auth_store.dart';

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.skinType = '',
    this.concerns = const [],
    this.ownedItems = const [],
    this.avoidItems = const [],
  });

  final int id;
  final String email;
  final String displayName;
  final String skinType;
  final List<String> concerns;
  final List<String> ownedItems;
  final List<String> avoidItems;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        skinType: json['skin_type'] as String? ?? '',
        concerns: ((json['concerns'] as List?) ?? []).map((e) => '$e').toList(),
        ownedItems: ((json['owned_items'] as List?) ?? []).map((e) => '$e').toList(),
        avoidItems: ((json['avoid_items'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class ProfileApi {
  ProfileApi({Dio? dio, AuthStore? store})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
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

  Future<UserProfile> me() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/profile/me',
      options: await _auth(),
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> patch({
    String? skinType,
    List<String>? concerns,
    List<String>? ownedItems,
    List<String>? avoidItems,
    String? displayName,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/profile/me',
      data: {
        if (skinType != null) 'skin_type': skinType,
        if (concerns != null) 'concerns': concerns,
        if (ownedItems != null) 'owned_items': ownedItems,
        if (avoidItems != null) 'avoid_items': avoidItems,
        if (displayName != null) 'display_name': displayName,
      },
      options: await _auth(),
    );
    return UserProfile.fromJson(response.data!);
  }
}
