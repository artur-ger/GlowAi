class AnalyzeResult {
  AnalyzeResult({
    required this.mode,
    required this.climate,
    required this.skin,
    required this.carePlan,
    required this.packingList,
    required this.packingKit,
    required this.productHints,
    required this.whyReasons,
    required this.forecastSummary,
    required this.followUpHint,
    required this.disclaimer,
    required this.provider,
    this.tripStart,
    this.tripEnd,
    this.tripDays,
  });

  final String mode;
  final ClimateSummary climate;
  final SkinAssessment skin;
  final List<CareStep> carePlan;
  final List<String> packingList;
  final List<PackingItem> packingKit;
  final List<String> productHints;
  final List<String> whyReasons;
  final String forecastSummary;
  final String followUpHint;
  final String disclaimer;
  final String provider;
  final String? tripStart;
  final String? tripEnd;
  final int? tripDays;

  bool get isLlmEngine =>
      skin.engine == 'llm' || skin.engine == 'llm_vision' || provider != 'rule_based';

  String get engineLabel {
    switch (skin.engine) {
      case 'llm_vision':
        return 'Нейросеть + фото';
      case 'llm':
        return 'Нейросеть';
      default:
        return 'Правила (без LLM)';
    }
  }

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    final kit = ((json['packing_kit'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => PackingItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final packingList = ((json['packing_list'] as List?) ?? []).map((e) => '$e').toList();
    return AnalyzeResult(
      mode: json['mode'] as String? ?? 'pre_trip',
      climate: ClimateSummary.fromJson(json['climate'] as Map<String, dynamic>),
      skin: SkinAssessment.fromJson(json['skin'] as Map<String, dynamic>),
      carePlan: ((json['care_plan'] as List?) ?? [])
          .map((e) => CareStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      packingList: packingList.isNotEmpty
          ? packingList
          : kit.where((e) => e.action == 'take').map((e) => e.item).toList(),
      packingKit: kit,
      productHints: ((json['product_hints'] as List?) ?? []).map((e) => '$e').toList(),
      whyReasons: ((json['why_reasons'] as List?) ?? []).map((e) => '$e').toList(),
      forecastSummary: json['forecast_summary'] as String? ?? '',
      followUpHint: json['follow_up_hint'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      tripStart: json['trip_start'] as String?,
      tripEnd: json['trip_end'] as String?,
      tripDays: (json['trip_days'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'climate': climate.toJson(),
        'skin': skin.toJson(),
        'care_plan': carePlan.map((e) => e.toJson()).toList(),
        'packing_list': packingList,
        'packing_kit': packingKit.map((e) => e.toJson()).toList(),
        'product_hints': productHints,
        'why_reasons': whyReasons,
        'forecast_summary': forecastSummary,
        'follow_up_hint': followUpHint,
        'disclaimer': disclaimer,
        'provider': provider,
        'trip_start': tripStart,
        'trip_end': tripEnd,
        'trip_days': tripDays,
      };
}

class PackingItem {
  PackingItem({required this.item, required this.action, required this.reason});

  final String item;
  final String action; // take | skip
  final String reason;

  factory PackingItem.fromJson(Map<String, dynamic> json) {
    return PackingItem(
      item: json['item'] as String? ?? '',
      action: json['action'] as String? ?? 'take',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item,
        'action': action,
        'reason': reason,
      };
}

class ClimateSummary {
  ClimateSummary({
    required this.homeCity,
    required this.destinationCity,
    this.homeTempC,
    this.destinationTempC,
    this.homeHumidity,
    this.destinationHumidity,
    this.destinationUv,
    this.deltaTempC,
    this.deltaHumidity,
    required this.risks,
    this.window = 'current',
    this.windowNote = '',
  });

  final String homeCity;
  final String destinationCity;
  final double? homeTempC;
  final double? destinationTempC;
  final double? homeHumidity;
  final double? destinationHumidity;
  final double? destinationUv;
  final double? deltaTempC;
  final double? deltaHumidity;
  final List<String> risks;
  final String window;
  final String windowNote;

  String get windowLabel {
    switch (window) {
      case 'forecast':
        return 'Прогноз на даты поездки';
      case 'seasonal_proxy':
        return 'Сезонный ориентир (архив)';
      default:
        return 'Погода сейчас';
    }
  }

  factory ClimateSummary.fromJson(Map<String, dynamic> json) {
    return ClimateSummary(
      homeCity: json['home_city'] as String? ?? '',
      destinationCity: json['destination_city'] as String? ?? '',
      homeTempC: (json['home_temp_c'] as num?)?.toDouble(),
      destinationTempC: (json['destination_temp_c'] as num?)?.toDouble(),
      homeHumidity: (json['home_humidity'] as num?)?.toDouble(),
      destinationHumidity: (json['destination_humidity'] as num?)?.toDouble(),
      destinationUv: (json['destination_uv'] as num?)?.toDouble(),
      deltaTempC: (json['delta_temp_c'] as num?)?.toDouble(),
      deltaHumidity: (json['delta_humidity'] as num?)?.toDouble(),
      risks: ((json['risks'] as List?) ?? []).map((e) => '$e').toList(),
      window: json['window'] as String? ?? 'current',
      windowNote: json['window_note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'home_city': homeCity,
        'destination_city': destinationCity,
        'home_temp_c': homeTempC,
        'destination_temp_c': destinationTempC,
        'home_humidity': homeHumidity,
        'destination_humidity': destinationHumidity,
        'destination_uv': destinationUv,
        'delta_temp_c': deltaTempC,
        'delta_humidity': deltaHumidity,
        'risks': risks,
        'window': window,
        'window_note': windowNote,
      };
}

class SkinAssessment {
  SkinAssessment({
    required this.summary,
    required this.concerns,
    required this.confidence,
    required this.engine,
  });

  final String summary;
  final List<String> concerns;
  final String confidence;
  final String engine;

  factory SkinAssessment.fromJson(Map<String, dynamic> json) {
    return SkinAssessment(
      summary: json['summary'] as String? ?? '',
      concerns: ((json['concerns'] as List?) ?? []).map((e) => '$e').toList(),
      confidence: json['confidence'] as String? ?? 'medium',
      engine: json['engine'] as String? ?? 'rule_based',
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'concerns': concerns,
        'confidence': confidence,
        'engine': engine,
      };
}

class CareStep {
  CareStep({required this.step, required this.title, required this.detail});

  final int step;
  final String title;
  final String detail;

  factory CareStep.fromJson(Map<String, dynamic> json) {
    return CareStep(
      step: (json['step'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'step': step,
        'title': title,
        'detail': detail,
      };
}
