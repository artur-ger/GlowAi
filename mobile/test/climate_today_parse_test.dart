import 'package:flutter_test/flutter_test.dart';
import 'package:glowai/data/climate_models.dart';
import 'package:glowai/l10n/strings.dart';

void main() {
  test('ClimateTodayResult parses API payload', () {
    final result = ClimateTodayResult.fromJson({
      'city': 'Москва',
      'sensation': -1,
      'sensation_label': 'прохладно',
      'confidence': 'medium',
      'calibration_note': 'пока без личной калибровки',
      'clothing': [
        {'item': 'лёгкая куртка', 'layer': 'outer'},
      ],
      'care': [
        {'item': 'SPF', 'reason': 'UV'},
      ],
      'appearance_risk': 1,
      'appearance_note': 'ветер',
      'why': ['ощущаемая 10°C'],
      'disclaimer': 'не медуслуга',
      'temp_c': 8.0,
    });
    expect(result.city, 'Москва');
    expect(result.sensation, -1);
    expect(result.clothing.single.item, 'лёгкая куртка');
    expect(result.care.single.reason, 'UV');
  });

  test('RU strings expose today and trip nav', () {
    expect(S.text('nav.today', 'ru'), 'Сегодня');
    expect(S.text('nav.trip', 'ru'), 'Поездка');
    expect(S.text('today.slogan', 'ru'), contains('Погода'));
    expect(S.text('nav.today', 'en'), 'Today');
  });
}
