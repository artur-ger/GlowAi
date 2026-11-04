import 'package:dio/dio.dart';

import '../core/config.dart';
import 'app_sync.dart';
import 'auth_store.dart';
import 'models.dart';

class CheckListItem {
  CheckListItem({
    required this.id,
    required this.mode,
    required this.homeCity,
    required this.destCity,
    required this.forecastSummary,
    required this.engine,
    this.createdAt,
    this.parentCheckId,
    this.remindAt,
  });

  final int id;
  final String mode;
  final String homeCity;
  final String destCity;
  final String forecastSummary;
  final String engine;
  final String? createdAt;
  final int? parentCheckId;
  final String? remindAt;

  factory CheckListItem.fromJson(Map<String, dynamic> json) => CheckListItem(
        id: (json['id'] as num).toInt(),
        mode: json['mode'] as String? ?? 'pre_trip',
        homeCity: json['home_city'] as String? ?? '',
        destCity: json['dest_city'] as String? ?? '',
        forecastSummary: json['forecast_summary'] as String? ?? '',
        engine: json['engine'] as String? ?? '',
        createdAt: json['created_at']?.toString(),
        parentCheckId: (json['parent_check_id'] as num?)?.toInt(),
        remindAt: json['remind_at']?.toString(),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
  });

  final int id;
  final String role;
  final String text;
  final String? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        role: json['role'] as String? ?? 'user',
        text: json['text'] as String? ?? '',
        createdAt: json['created_at']?.toString(),
      );
}

class ChecksApi {
  ChecksApi({Dio? dio, AuthStore? store})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _store = store ?? AuthStore();

  final Dio _dio;
  final AuthStore _store;

  Future<Options> _authOptions() async {
    final token = await _store.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('login required');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<CheckListItem> saveCheck({
    required AnalyzeResult result,
    required String homeCity,
    required String destCity,
    int? parentCheckId,
    int? remindInHours,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/checks',
      data: {
        'payload': result.toJson(),
        'home_city': homeCity,
        'dest_city': destCity,
        'mode': result.mode,
        if (parentCheckId != null) 'parent_check_id': parentCheckId,
        if (remindInHours != null) 'remind_in_hours': remindInHours,
      },
      options: await _authOptions(),
    );
    final item = CheckListItem.fromJson(response.data!);
    AppSync.instance.checksChanged();
    return item;
  }

  Future<CheckListItem> setRemind({required int checkId, int hours = 48}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/checks/$checkId/remind',
      data: {'hours': hours},
      options: await _authOptions(),
    );
    final item = CheckListItem.fromJson(response.data!);
    AppSync.instance.checksChanged();
    return item;
  }

  Future<List<CheckListItem>> listChecks() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/checks',
      options: await _authOptions(),
    );
    return (response.data ?? [])
        .whereType<Map>()
        .map((e) => CheckListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CheckListItem>> listDueReminders() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/checks/due',
      options: await _authOptions(),
    );
    return (response.data ?? [])
        .whereType<Map>()
        .map((e) => CheckListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AnalyzeResult> getCheckPayload(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/checks/$id',
      options: await _authOptions(),
    );
    final payload = Map<String, dynamic>.from(response.data?['payload'] as Map);
    return AnalyzeResult.fromJson(payload);
  }

  Future<List<ChatMessage>> listMessages(int checkId) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/checks/$checkId/messages',
      options: await _authOptions(),
    );
    return (response.data ?? [])
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMessage> sendMessage(int checkId, String text) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/checks/$checkId/messages',
      data: {'text': text},
      options: await _authOptions(),
    );
    return ChatMessage.fromJson(
      Map<String, dynamic>.from(response.data?['assistant_message'] as Map),
    );
  }

  Future<Map<String, dynamic>> submitCheckIn({
    required int checkId,
    required int dryness,
    required int oiliness,
    required int calmness,
    required int redness,
    String note = '',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/checks/$checkId/checkin',
      data: {
        'dryness': dryness,
        'oiliness': oiliness,
        'calmness': calmness,
        'redness': redness,
        'note': note,
      },
      options: await _authOptions(),
    );
    return response.data!;
  }

  Future<void> deleteCheck(int checkId) async {
    await _dio.delete<void>(
      '/api/v1/checks/$checkId',
      options: await _authOptions(),
    );
    AppSync.instance.checksChanged();
  }
}
