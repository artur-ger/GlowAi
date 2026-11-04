import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import 'models.dart';

class AnalyzeApi {
  AnalyzeApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 90),
              ),
            );

  final Dio _dio;

  Future<AnalyzeResult> analyze({
    required String homeCity,
    required String destinationCity,
    required String skinType,
    required String concerns,
    required String mode,
    String tripStart = '',
    String tripEnd = '',
    String ownedItems = '',
    String avoidItems = '',
    double? homeLat,
    double? homeLon,
    double? destLat,
    double? destLon,
    XFile? photo,
  }) async {
    MultipartFile? photoPart;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final name = photo.name.isNotEmpty ? photo.name : 'selfie.jpg';
      photoPart = MultipartFile.fromBytes(
        bytes,
        filename: name,
        contentType: MediaType('image', 'jpeg'),
      );
    }

    final form = FormData.fromMap({
      'home_city': homeCity,
      'destination_city': destinationCity,
      'skin_type': skinType,
      'concerns': concerns,
      'mode': mode,
      'trip_start': tripStart,
      'trip_end': tripEnd,
      'owned_items': ownedItems,
      'avoid_items': avoidItems,
      if (homeLat != null) 'home_lat': homeLat.toString(),
      if (homeLon != null) 'home_lon': homeLon.toString(),
      if (destLat != null) 'dest_lat': destLat.toString(),
      if (destLon != null) 'dest_lon': destLon.toString(),
      if (photoPart != null) 'photo': photoPart,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/analyze',
      data: form,
    );
    return AnalyzeResult.fromJson(response.data!);
  }
}
