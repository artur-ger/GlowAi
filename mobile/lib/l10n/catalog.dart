/// Selectable chips with stable ids; UI shows [label], API gets Russian [api].
class LocOption {
  const LocOption({required this.id, required this.ru, required this.en});
  final String id;
  final String ru;
  final String en;

  String label(String lang) => lang == 'en' ? en : ru;
  String get api => ru;
}

const skinTypeOptions = <LocOption>[
  LocOption(id: 'normal', ru: 'Нормальная', en: 'Normal'),
  LocOption(id: 'dry', ru: 'Сухая', en: 'Dry'),
  LocOption(id: 'oily', ru: 'Жирная', en: 'Oily'),
  LocOption(id: 'combo', ru: 'Комбинированная', en: 'Combination'),
  LocOption(id: 'sensitive', ru: 'Чувствительная', en: 'Sensitive'),
];

const concernChipOptions = <LocOption>[
  LocOption(id: 'dryness', ru: 'Сухость', en: 'Dryness'),
  LocOption(id: 'oil', ru: 'Жирный блеск', en: 'Oiliness'),
  LocOption(id: 'irritation', ru: 'Раздражение', en: 'Irritation'),
  LocOption(id: 'redness', ru: 'Покраснение', en: 'Redness'),
  LocOption(id: 'acne', ru: 'Акне', en: 'Acne'),
  LocOption(id: 'pigment', ru: 'Пигментация', en: 'Pigmentation'),
  LocOption(id: 'dull', ru: 'Тусклость', en: 'Dullness'),
  LocOption(id: 'sensitivity', ru: 'Чувствительность', en: 'Sensitivity'),
  LocOption(id: 'sunburn', ru: 'Солнечный ожог', en: 'Sunburn'),
  LocOption(id: 'acclimate', ru: 'Акклиматизация', en: 'Acclimatization'),
];

const ownedChipOptions = <LocOption>[
  LocOption(id: 'spf', ru: 'SPF', en: 'SPF'),
  LocOption(id: 'cleanser', ru: 'Cleanser', en: 'Cleanser'),
  LocOption(id: 'moisturizer', ru: 'Moisturizer', en: 'Moisturizer'),
  LocOption(id: 'mist', ru: 'Mist', en: 'Mist'),
  LocOption(id: 'spot', ru: 'Spot', en: 'Spot'),
  LocOption(id: 'retinoid', ru: 'Retinoid', en: 'Retinoid'),
  LocOption(id: 'acids', ru: 'Acids', en: 'Acids'),
];

const avoidChipOptions = <LocOption>[
  LocOption(id: 'acids', ru: 'Acids', en: 'Acids'),
  LocOption(id: 'retinoid', ru: 'Retinoid', en: 'Retinoid'),
  LocOption(id: 'fragrance', ru: 'Fragrance', en: 'Fragrance'),
  LocOption(id: 'alcohol', ru: 'Alcohol', en: 'Alcohol'),
  LocOption(id: 'scrub', ru: 'Scrub', en: 'Scrub'),
  LocOption(id: 'new_actives', ru: 'Новые активы', en: 'New actives'),
];

String? _matchId(List<LocOption> options, String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  for (final o in options) {
    if (o.id == v || o.ru == v || o.en == v) return o.id;
  }
  return null;
}

/// Map stored label/id → option id; unknown stays as custom free text.
Set<String> normalizeIds(Set<String> raw, List<LocOption> options) {
  final out = <String>{};
  for (final r in raw) {
    final id = _matchId(options, r);
    out.add(id ?? r.trim());
  }
  return out..removeWhere((e) => e.isEmpty);
}

String skinApiValue(String stored) {
  final id = _matchId(skinTypeOptions, stored);
  if (id == null) return stored;
  return skinTypeOptions.firstWhere((o) => o.id == id).api;
}

String labelsForApi(Set<String> selected, List<LocOption> options) {
  return selected.map((s) {
    final id = _matchId(options, s);
    if (id == null) return s;
    return options.firstWhere((o) => o.id == id).api;
  }).join(', ');
}

String displayLabel(String selected, List<LocOption> options, String lang) {
  final id = _matchId(options, selected);
  if (id == null) return selected;
  return options.firstWhere((o) => o.id == id).label(lang);
}
