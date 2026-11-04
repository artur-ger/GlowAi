/// Страны — конечный справочник (ISO). Города НЕ хардкодим: ищем через API.
class CountryOption {
  const CountryOption({required this.code, required this.nameRu});

  final String code; // ISO-3166-1 alpha-2, пустой = поиск по всему миру
  final String nameRu;

  bool get isWorldwide => code.isEmpty;
}

const worldwideCountry = CountryOption(code: '', nameRu: 'Все страны мира');

const countries = <CountryOption>[
  worldwideCountry,
  CountryOption(code: 'RU', nameRu: 'Россия'),
  CountryOption(code: 'TR', nameRu: 'Турция'),
  CountryOption(code: 'AE', nameRu: 'ОАЭ'),
  CountryOption(code: 'EG', nameRu: 'Египет'),
  CountryOption(code: 'TH', nameRu: 'Таиланд'),
  CountryOption(code: 'ID', nameRu: 'Индонезия'),
  CountryOption(code: 'IN', nameRu: 'Индия'),
  CountryOption(code: 'VN', nameRu: 'Вьетнам'),
  CountryOption(code: 'GE', nameRu: 'Грузия'),
  CountryOption(code: 'AM', nameRu: 'Армения'),
  CountryOption(code: 'AZ', nameRu: 'Азербайджан'),
  CountryOption(code: 'KZ', nameRu: 'Казахстан'),
  CountryOption(code: 'BY', nameRu: 'Беларусь'),
  CountryOption(code: 'UZ', nameRu: 'Узбекистан'),
  CountryOption(code: 'KG', nameRu: 'Кыргызстан'),
  CountryOption(code: 'TJ', nameRu: 'Таджикистан'),
  CountryOption(code: 'MV', nameRu: 'Мальдивы'),
  CountryOption(code: 'LK', nameRu: 'Шри-Ланка'),
  CountryOption(code: 'CN', nameRu: 'Китай'),
  CountryOption(code: 'JP', nameRu: 'Япония'),
  CountryOption(code: 'KR', nameRu: 'Южная Корея'),
  CountryOption(code: 'SG', nameRu: 'Сингапур'),
  CountryOption(code: 'MY', nameRu: 'Малайзия'),
  CountryOption(code: 'PH', nameRu: 'Филиппины'),
  CountryOption(code: 'GR', nameRu: 'Греция'),
  CountryOption(code: 'CY', nameRu: 'Кипр'),
  CountryOption(code: 'IT', nameRu: 'Италия'),
  CountryOption(code: 'ES', nameRu: 'Испания'),
  CountryOption(code: 'FR', nameRu: 'Франция'),
  CountryOption(code: 'DE', nameRu: 'Германия'),
  CountryOption(code: 'AT', nameRu: 'Австрия'),
  CountryOption(code: 'CH', nameRu: 'Швейцария'),
  CountryOption(code: 'CZ', nameRu: 'Чехия'),
  CountryOption(code: 'HU', nameRu: 'Венгрия'),
  CountryOption(code: 'PL', nameRu: 'Польша'),
  CountryOption(code: 'PT', nameRu: 'Португалия'),
  CountryOption(code: 'GB', nameRu: 'Великобритания'),
  CountryOption(code: 'IE', nameRu: 'Ирландия'),
  CountryOption(code: 'NL', nameRu: 'Нидерланды'),
  CountryOption(code: 'BE', nameRu: 'Бельгия'),
  CountryOption(code: 'SE', nameRu: 'Швеция'),
  CountryOption(code: 'NO', nameRu: 'Норвегия'),
  CountryOption(code: 'FI', nameRu: 'Финляндия'),
  CountryOption(code: 'DK', nameRu: 'Дания'),
  CountryOption(code: 'US', nameRu: 'США'),
  CountryOption(code: 'CA', nameRu: 'Канада'),
  CountryOption(code: 'MX', nameRu: 'Мексика'),
  CountryOption(code: 'BR', nameRu: 'Бразилия'),
  CountryOption(code: 'AR', nameRu: 'Аргентина'),
  CountryOption(code: 'ZA', nameRu: 'ЮАР'),
  CountryOption(code: 'MA', nameRu: 'Марокко'),
  CountryOption(code: 'TN', nameRu: 'Тунис'),
  CountryOption(code: 'IL', nameRu: 'Израиль'),
  CountryOption(code: 'JO', nameRu: 'Иордания'),
  CountryOption(code: 'QA', nameRu: 'Катар'),
  CountryOption(code: 'BH', nameRu: 'Бахрейн'),
  CountryOption(code: 'OM', nameRu: 'Оман'),
  CountryOption(code: 'SA', nameRu: 'Саудовская Аравия'),
  CountryOption(code: 'AU', nameRu: 'Австралия'),
  CountryOption(code: 'NZ', nameRu: 'Новая Зеландия'),
];

CountryOption? countryByCode(String code) {
  final upper = code.toUpperCase();
  for (final c in countries) {
    if (c.code == upper) return c;
  }
  return null;
}
