class ClimateProfilePayload {
  const ClimateProfilePayload({
    this.coldBias = 0,
    this.heatBias = 0,
    this.activity = 'moderate',
    this.ageBand = 'unknown',
    this.sex = 'unknown',
    this.feedbackOffset = 0,
    this.feedbackCount = 0,
    this.habits = const [],
    this.allergies = const [],
    this.leaveHour = 8,
    this.returnHour = 19,
  });

  final double coldBias;
  final double heatBias;
  final String activity;
  final String ageBand;
  final String sex;
  final double feedbackOffset;
  final int feedbackCount;
  final List<String> habits;
  final List<String> allergies;
  final int leaveHour;
  final int returnHour;

  Map<String, dynamic> toJson() => {
        'cold_bias': coldBias,
        'heat_bias': heatBias,
        'activity': activity,
        'age_band': ageBand,
        'sex': sex,
        'feedback_offset': feedbackOffset,
        'feedback_count': feedbackCount,
        'habits': habits,
        'allergies': allergies,
        'leave_hour': leaveHour,
        'return_hour': returnHour,
      };
}

class ClothingLine {
  const ClothingLine({required this.item, required this.layer, this.clo, this.catalogId});
  final String item;
  final String layer;
  final double? clo;
  final String? catalogId;

  factory ClothingLine.fromJson(Map<String, dynamic> json) => ClothingLine(
        item: json['item'] as String? ?? '',
        layer: json['layer'] as String? ?? 'mid',
        clo: (json['clo'] as num?)?.toDouble(),
        catalogId: json['catalog_id'] as String?,
      );
}

class CareLine {
  const CareLine({required this.item, required this.reason, this.catalogId});
  final String item;
  final String reason;
  final String? catalogId;

  factory CareLine.fromJson(Map<String, dynamic> json) => CareLine(
        item: json['item'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        catalogId: json['catalog_id'] as String?,
      );
}

class HourlySensation {
  const HourlySensation({
    required this.time,
    required this.hourLabel,
    required this.utciC,
    required this.sensation,
    required this.sensationLabel,
    this.tempC,
    this.windMs,
    this.precipMm,
  });

  final String time;
  final String hourLabel;
  final double utciC;
  final int sensation;
  final String sensationLabel;
  final double? tempC;
  final double? windMs;
  final double? precipMm;

  factory HourlySensation.fromJson(Map<String, dynamic> json) => HourlySensation(
        time: json['time'] as String? ?? '',
        hourLabel: json['hour_label'] as String? ?? '',
        utciC: (json['utci_c'] as num?)?.toDouble() ?? 0,
        sensation: (json['sensation'] as num?)?.toInt() ?? 0,
        sensationLabel: json['sensation_label'] as String? ?? '',
        tempC: (json['temp_c'] as num?)?.toDouble(),
        windMs: (json['wind_ms'] as num?)?.toDouble(),
        precipMm: (json['precip_mm'] as num?)?.toDouble(),
      );
}

class SupportIndices {
  const SupportIndices({
    required this.ireqClo,
    required this.metWm2,
    this.petC,
    this.heatIndexC,
    this.humidexC,
    this.windChillC,
  });

  final double? petC;
  final double? heatIndexC;
  final double? humidexC;
  final double? windChillC;
  final double ireqClo;
  final double metWm2;

  factory SupportIndices.fromJson(Map<String, dynamic> json) => SupportIndices(
        petC: (json['pet_c'] as num?)?.toDouble(),
        heatIndexC: (json['heat_index_c'] as num?)?.toDouble(),
        humidexC: (json['humidex_c'] as num?)?.toDouble(),
        windChillC: (json['wind_chill_c'] as num?)?.toDouble(),
        ireqClo: (json['ireq_clo'] as num?)?.toDouble() ?? 0.6,
        metWm2: (json['met_w_m2'] as num?)?.toDouble() ?? 115,
      );
}

class FeedbackWindow {
  const FeedbackWindow({
    required this.moment,
    required this.leaveHour,
    required this.returnHour,
    required this.prompt,
  });

  final String moment;
  final int leaveHour;
  final int returnHour;
  final String prompt;

  factory FeedbackWindow.fromJson(Map<String, dynamic> json) => FeedbackWindow(
        moment: json['moment'] as String? ?? 'anytime',
        leaveHour: (json['leave_hour'] as num?)?.toInt() ?? 8,
        returnHour: (json['return_hour'] as num?)?.toInt() ?? 19,
        prompt: json['prompt'] as String? ?? '',
      );
}

class ClimateTodayResult {
  const ClimateTodayResult({
    required this.city,
    required this.utciC,
    required this.utciStress,
    required this.personalUtciC,
    required this.sensation,
    required this.sensationLabel,
    required this.confidence,
    required this.calibrationNote,
    required this.explanation,
    required this.spareLayer,
    required this.spareLayerNote,
    required this.support,
    required this.clothing,
    required this.care,
    required this.appearanceRisk,
    required this.appearanceNote,
    required this.hours,
    required this.why,
    required this.disclaimer,
    required this.provider,
    this.tempC,
    this.humidity,
    this.windMs,
    this.uv,
    this.modelSpreadC,
    this.placeOffsetC,
    this.randomInterceptC,
    this.feedbackWindow,
    this.llmUsed = false,
  });

  final String city;
  final double utciC;
  final String utciStress;
  final double personalUtciC;
  final int sensation;
  final String sensationLabel;
  final String confidence;
  final String calibrationNote;
  final String explanation;
  final bool spareLayer;
  final String spareLayerNote;
  final SupportIndices support;
  final List<ClothingLine> clothing;
  final List<CareLine> care;
  final int appearanceRisk;
  final String appearanceNote;
  final List<HourlySensation> hours;
  final List<String> why;
  final String disclaimer;
  final String provider;
  final double? tempC;
  final double? humidity;
  final double? windMs;
  final double? uv;
  final double? modelSpreadC;
  final double? placeOffsetC;
  final double? randomInterceptC;
  final FeedbackWindow? feedbackWindow;
  final bool llmUsed;

  factory ClimateTodayResult.fromJson(Map<String, dynamic> json) {
    return ClimateTodayResult(
      city: json['city'] as String? ?? '',
      utciC: (json['utci_c'] as num?)?.toDouble() ?? 0,
      utciStress: json['utci_stress'] as String? ?? '',
      personalUtciC: (json['personal_utci_c'] as num?)?.toDouble() ?? 0,
      sensation: (json['sensation'] as num?)?.toInt() ?? 0,
      sensationLabel: json['sensation_label'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'medium',
      calibrationNote: json['calibration_note'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      spareLayer: json['spare_layer'] as bool? ?? false,
      spareLayerNote: json['spare_layer_note'] as String? ?? '',
      support: SupportIndices.fromJson(
        (json['support'] as Map<String, dynamic>?) ?? {'ireq_clo': 0.6, 'met_w_m2': 115},
      ),
      clothing: (json['clothing'] as List<dynamic>? ?? [])
          .map((e) => ClothingLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      care: (json['care'] as List<dynamic>? ?? [])
          .map((e) => CareLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      appearanceRisk: (json['appearance_risk'] as num?)?.toInt() ?? 0,
      appearanceNote: json['appearance_note'] as String? ?? '',
      hours: (json['hours'] as List<dynamic>? ?? [])
          .map((e) => HourlySensation.fromJson(e as Map<String, dynamic>))
          .toList(),
      why: (json['why'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      tempC: (json['temp_c'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      windMs: (json['wind_ms'] as num?)?.toDouble(),
      uv: (json['uv'] as num?)?.toDouble(),
      modelSpreadC: (json['model_spread_c'] as num?)?.toDouble(),
      placeOffsetC: (json['place_offset_c'] as num?)?.toDouble(),
      randomInterceptC: (json['random_intercept_c'] as num?)?.toDouble(),
      feedbackWindow: json['feedback_window'] is Map<String, dynamic>
          ? FeedbackWindow.fromJson(json['feedback_window'] as Map<String, dynamic>)
          : null,
      llmUsed: json['llm_used'] as bool? ?? false,
    );
  }
}

class ClimateFeedbackResult {
  const ClimateFeedbackResult({
    required this.ok,
    required this.suggestedFeedbackOffsetDelta,
    required this.feedbackCount,
    required this.message,
    this.placeOffsetDelta = 0,
    this.feedbackOffset,
  });

  final bool ok;
  final double suggestedFeedbackOffsetDelta;
  final double placeOffsetDelta;
  final double? feedbackOffset;
  final int feedbackCount;
  final String message;

  factory ClimateFeedbackResult.fromJson(Map<String, dynamic> json) {
    return ClimateFeedbackResult(
      ok: json['ok'] as bool? ?? true,
      suggestedFeedbackOffsetDelta:
          (json['suggested_feedback_offset_delta'] as num?)?.toDouble() ?? 0,
      placeOffsetDelta: (json['place_offset_delta'] as num?)?.toDouble() ?? 0,
      feedbackOffset: (json['feedback_offset'] as num?)?.toDouble(),
      feedbackCount: (json['feedback_count'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class ClimateAccountProfile {
  const ClimateAccountProfile({
    required this.onboarded,
    required this.cityName,
    required this.cityCountry,
    required this.cityCountryCode,
    this.lat,
    this.lon,
    this.coldBias = 0,
    this.heatBias = 0,
    this.activity = 'moderate',
    this.ageBand = 'unknown',
    this.sex = 'unknown',
    this.feedbackOffset = 0,
    this.feedbackCount = 0,
    this.habits = const [],
    this.allergies = const [],
    this.skinNote = '',
    this.leaveHour = 8,
    this.returnHour = 19,
    this.clientKey = 'anon',
  });

  final bool onboarded;
  final String cityName;
  final String cityCountry;
  final String cityCountryCode;
  final double? lat;
  final double? lon;
  final double coldBias;
  final double heatBias;
  final String activity;
  final String ageBand;
  final String sex;
  final double feedbackOffset;
  final int feedbackCount;
  final List<String> habits;
  final List<String> allergies;
  final String skinNote;
  final int leaveHour;
  final int returnHour;
  final String clientKey;

  factory ClimateAccountProfile.fromJson(Map<String, dynamic> json) {
    return ClimateAccountProfile(
      onboarded: json['onboarded'] as bool? ?? false,
      cityName: json['city_name'] as String? ?? 'Москва',
      cityCountry: json['city_country'] as String? ?? 'Россия',
      cityCountryCode: json['city_country_code'] as String? ?? 'RU',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      coldBias: (json['cold_bias'] as num?)?.toDouble() ?? 0,
      heatBias: (json['heat_bias'] as num?)?.toDouble() ?? 0,
      activity: json['activity'] as String? ?? 'moderate',
      ageBand: json['age_band'] as String? ?? 'unknown',
      sex: json['sex'] as String? ?? 'unknown',
      feedbackOffset: (json['feedback_offset'] as num?)?.toDouble() ?? 0,
      feedbackCount: (json['feedback_count'] as num?)?.toInt() ?? 0,
      habits: (json['habits'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      allergies: (json['allergies'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      skinNote: json['skin_note'] as String? ?? '',
      leaveHour: (json['leave_hour'] as num?)?.toInt() ?? 8,
      returnHour: (json['return_hour'] as num?)?.toInt() ?? 19,
      clientKey: json['client_key'] as String? ?? 'anon',
    );
  }

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'city_name': cityName,
        'city_country': cityCountry,
        'city_country_code': cityCountryCode,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'cold_bias': coldBias,
        'heat_bias': heatBias,
        'activity': activity,
        'age_band': ageBand,
        'sex': sex,
        'feedback_offset': feedbackOffset,
        'feedback_count': feedbackCount,
        'habits': habits,
        'allergies': allergies,
        'skin_note': skinNote,
        'leave_hour': leaveHour,
        'return_hour': returnHour,
        'client_key': clientKey,
      };
}

class ClimatePlanResult {
  const ClimatePlanResult({required this.summary, required this.today, this.source = 'rules'});
  final String summary;
  final String source;
  final ClimateTodayResult today;

  factory ClimatePlanResult.fromJson(Map<String, dynamic> json) {
    final parsed = json['parsed'] as Map<String, dynamic>? ?? {};
    return ClimatePlanResult(
      summary: parsed['summary'] as String? ?? '',
      source: parsed['source'] as String? ?? 'rules',
      today: ClimateTodayResult.fromJson(json['today'] as Map<String, dynamic>),
    );
  }
}
