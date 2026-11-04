import 'package:flutter_test/flutter_test.dart';
import 'package:glowai/data/models.dart';

void main() {
  test('AnalyzeResult roundtrip keeps engine and provider', () {
    final json = {
      'mode': 'pre_trip',
      'climate': {
        'home_city': 'Москва',
        'destination_city': 'Анталия',
        'home_temp_c': 3,
        'destination_temp_c': 20,
        'home_humidity': 60,
        'destination_humidity': 80,
        'destination_uv': 3.5,
        'delta_temp_c': 17,
        'delta_humidity': 20,
        'risks': ['потепление'],
      },
      'skin': {
        'summary': 'ok',
        'concerns': ['Сухость'],
        'confidence': 'high',
        'engine': 'llm',
      },
      'care_plan': [
        {'step': 1, 'title': 'Очищение', 'detail': 'мягко'},
      ],
      'packing_list': ['SPF'],
      'packing_kit': [
        {'item': 'SPF', 'action': 'take', 'reason': 'UV'},
      ],
      'product_hints': ['moisturizer'],
      'why_reasons': ['ΔT'],
      'forecast_summary': 'тест',
      'follow_up_hint': '48-72',
      'disclaimer': 'не медуслуга',
      'provider': 'openai_compatible',
      'trip_days': 8,
    };

    final result = AnalyzeResult.fromJson(json);
    expect(result.isLlmEngine, isTrue);
    expect(result.engineLabel, contains('Нейросеть'));
    expect(result.skin.confidence, 'high');

    final again = AnalyzeResult.fromJson(result.toJson());
    expect(again.provider, 'openai_compatible');
    expect(again.skin.engine, 'llm');
    expect(again.carePlan.first.title, 'Очищение');
  });
}
