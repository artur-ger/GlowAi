import 'countries.dart';

class PlaceOption {
  const PlaceOption({
    required this.name,
    required this.country,
    required this.countryCode,
    this.admin1,
    this.latitude,
    this.longitude,
    this.label,
  });

  final String name;
  final String country;
  final String countryCode;
  final String? admin1;
  final double? latitude;
  final double? longitude;
  final String? label;

  String get displayLabel => label ?? [name, if (admin1 != null) admin1!, country].join(', ');

  factory PlaceOption.fromJson(Map<String, dynamic> json) {
    return PlaceOption(
      name: json['name'] as String? ?? '',
      country: json['country'] as String? ?? '',
      countryCode: (json['country_code'] as String? ?? '').toUpperCase(),
      admin1: json['admin1'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      label: json['label'] as String?,
    );
  }
}

const skinTypes = <String>[
  'Нормальная',
  'Сухая',
  'Жирная',
  'Комбинированная',
  'Чувствительная',
];

const concernOptions = <String>[
  'Сухость',
  'Жирный блеск',
  'Раздражение',
  'Покраснение',
  'Акне',
  'Пигментация',
  'Тусклость',
  'Чувствительность',
  'Солнечный ожог',
  'Акклиматизация',
];

/// Что уже есть в travel-кейсе (влияет на packing take→skip).
const ownedKitOptions = <String>[
  'SPF',
  'Cleanser',
  'Moisturizer',
  'Mist',
  'Spot',
  'Retinoid',
  'Acids',
];

/// Чего избегать в поездке / при возврате.
const avoidKitOptions = <String>[
  'Retinoid',
  'Acids',
  'Fragrance',
  'New products',
  'Alcohol toner',
];

final defaultHome = PlaceOption(
  name: 'Москва',
  country: 'Россия',
  countryCode: 'RU',
  latitude: 55.75204,
  longitude: 37.61781,
  label: 'Москва, Россия',
);

final defaultDestination = PlaceOption(
  name: 'Анталья',
  country: 'Турция',
  countryCode: 'TR',
  latitude: 36.90812,
  longitude: 30.69556,
  label: 'Анталья, Турция',
);

CountryOption defaultHomeCountry() => countryByCode('RU')!;
CountryOption defaultDestCountry() => countryByCode('TR')!;
