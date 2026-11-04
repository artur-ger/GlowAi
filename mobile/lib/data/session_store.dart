import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'places.dart';

/// Local-only last analysis for 48–72h follow-up (no accounts).
class SessionStore {
  static const _key = 'glowai_last_session_v1';

  Future<void> save({
    required AnalyzeResult result,
    required PlaceOption home,
    required PlaceOption destination,
    required String skinType,
    required Set<String> concerns,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'saved_at': DateTime.now().toIso8601String(),
      'home': _placeToJson(home),
      'destination': _placeToJson(destination),
      'skin_type': skinType,
      'concerns': concerns.toList(),
      'result': result.toJson(),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }

  Future<SavedSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SavedSession(
        savedAt: DateTime.tryParse(map['saved_at'] as String? ?? '') ?? DateTime.now(),
        home: _placeFromJson(Map<String, dynamic>.from(map['home'] as Map)),
        destination: _placeFromJson(Map<String, dynamic>.from(map['destination'] as Map)),
        skinType: map['skin_type'] as String? ?? '',
        concerns: ((map['concerns'] as List?) ?? []).map((e) => '$e').toSet(),
        result: AnalyzeResult.fromJson(Map<String, dynamic>.from(map['result'] as Map)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Map<String, dynamic> _placeToJson(PlaceOption p) => {
        'name': p.name,
        'country': p.country,
        'country_code': p.countryCode,
        'admin1': p.admin1,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'label': p.label,
      };

  PlaceOption _placeFromJson(Map<String, dynamic> json) => PlaceOption(
        name: json['name'] as String? ?? '',
        country: json['country'] as String? ?? '',
        countryCode: (json['country_code'] as String? ?? '').toUpperCase(),
        admin1: json['admin1'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        label: json['label'] as String?,
      );
}

class SavedSession {
  SavedSession({
    required this.savedAt,
    required this.home,
    required this.destination,
    required this.skinType,
    required this.concerns,
    required this.result,
  });

  final DateTime savedAt;
  final PlaceOption home;
  final PlaceOption destination;
  final String skinType;
  final Set<String> concerns;
  final AnalyzeResult result;

  /// Soft window for local hint: from 48h after save (SOS still always allowed in UI).
  bool get isFollowUpWindow {
    final hours = DateTime.now().difference(savedAt).inHours;
    return hours >= 48;
  }
}
