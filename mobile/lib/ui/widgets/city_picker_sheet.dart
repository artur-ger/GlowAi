import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/countries.dart';
import '../../data/geo_api.dart';
import '../../data/places.dart';

Future<PlaceOption?> showCityPickerSheet(
  BuildContext context, {
  required String title,
  PlaceOption? selected,
}) {
  return showModalBottomSheet<PlaceOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GlowColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _PlacePickerBody(title: title, selected: selected),
  );
}

class _PlacePickerBody extends StatefulWidget {
  const _PlacePickerBody({required this.title, this.selected});

  final String title;
  final PlaceOption? selected;

  @override
  State<_PlacePickerBody> createState() => _PlacePickerBodyState();
}

class _PlacePickerBodyState extends State<_PlacePickerBody> {
  final _geo = GeoApi();
  final _countryQuery = TextEditingController();
  final _cityQuery = TextEditingController();

  late CountryOption _country;
  List<CountryOption> _countryFiltered = countries;
  List<PlaceOption> _places = [];
  List<PlaceOption> _suggestions = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final code = widget.selected?.countryCode;
    _country = countryByCode(code ?? '') ??
        (widget.title.toLowerCase().contains('дом')
            ? countryByCode('RU')!
            : countryByCode('TR')!);
    final initialCity = widget.selected?.name;
    if (initialCity != null && initialCity.isNotEmpty) {
      _cityQuery.text = initialCity;
      _searchCities(initialCity);
    } else {
      _loadPopular();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _countryQuery.dispose();
    _cityQuery.dispose();
    super.dispose();
  }

  void _filterCountries(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _countryFiltered = q.isEmpty
          ? countries
          : countries
              .where(
                (c) =>
                    c.nameRu.toLowerCase().contains(q) ||
                    c.code.toLowerCase().contains(q),
              )
              .toList();
    });
  }

  void _onCityChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchCities(value);
    });
  }

  Future<void> _loadPopular() async {
    if (_country.isWorldwide) {
      setState(() {
        _places = [];
        _suggestions = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final hits = await _geo.popularPlaces(countryCode: _country.code);
    if (!mounted) return;
    setState(() {
      _places = hits;
      _suggestions = [];
      _loading = false;
      if (hits.isEmpty) {
        _error = 'Введите название города — поиск через Open-Meteo.';
      }
    });
  }

  Future<void> _searchCities(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      await _loadPopular();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hit = await _geo.searchPlaces(
        query: q,
        countryCode: _country.isWorldwide ? null : _country.code,
      );
      if (!mounted) return;
      setState(() {
        _places = hit.results;
        _suggestions = hit.suggestions;
        _loading = false;
        if (hit.results.isEmpty && hit.suggestions.isEmpty) {
          _error = _country.isWorldwide
              ? 'Ничего не найдено. Попробуйте латиницей, например Antalya.'
              : 'Ничего не найдено в ${_country.nameRu}. Попробуйте другое написание или «Все страны мира».';
        } else if (hit.results.isEmpty && hit.suggestions.isNotEmpty) {
          _error =
              'В ${_country.nameRu} нет совпадений — ниже города из других стран.';
        } else {
          _error = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось искать города. Проверьте, что backend запущен.';
      });
    }
  }

  Future<void> _pickCountry() async {
    _countryQuery.clear();
    _filterCountries('');
    final picked = await showModalBottomSheet<CountryOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GlowColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: GlowColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Страна',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _countryQuery,
                        autofocus: true,
                        onChanged: (v) {
                          _filterCountries(v);
                          setModalState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Найти страну',
                          prefixIcon: const Icon(Icons.public),
                          filled: true,
                          fillColor: GlowColors.mist,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _countryFiltered.length,
                        itemBuilder: (context, i) {
                          final c = _countryFiltered[i];
                          final selected = c.code == _country.code;
                          return ListTile(
                            title: Text(c.nameRu, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(c.code.isEmpty ? 'WORLD' : c.code),
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: GlowColors.sea)
                                : null,
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _country = picked;
      _places = [];
      _suggestions = [];
      _error = null;
    });
    if (_cityQuery.text.trim().length >= 2) {
      _searchCities(_cityQuery.text);
    } else {
      _loadPopular();
    }
  }

  Widget _placeTile(PlaceOption place, {required bool elsewhere}) {
    final selected = widget.selected?.name == place.name &&
        widget.selected?.countryCode == place.countryCode;
    return ListTile(
      title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          if (place.admin1 != null && place.admin1!.isNotEmpty) place.admin1!,
          place.country,
          if (elsewhere) '· другая страна',
        ].join(' · '),
      ),
      trailing: selected ? const Icon(Icons.check_circle, color: GlowColors.sea) : null,
      onTap: () => Navigator.pop(context, place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPopularHint =
        _cityQuery.text.trim().length < 2 && _places.isNotEmpty && _suggestions.isEmpty;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: GlowColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: _pickCountry,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: GlowColors.mist,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: GlowColors.sea),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Страна', style: TextStyle(fontSize: 12, color: GlowColors.muted)),
                            Text(
                              _country.nameRu,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _cityQuery,
                onChanged: _onCityChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Город: Анталья, Dubai, Phuket…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: GlowColors.mist,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Text(
                showPopularHint
                    ? 'Популярные города (Open-Meteo). Или введите свой.'
                    : 'Поиск: Open-Meteo Geocoding (тот же API, что у прогноза погоды).',
                style: const TextStyle(color: GlowColors.muted, fontSize: 12),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(_error!, style: const TextStyle(color: GlowColors.coral, fontSize: 13)),
              ),
            Expanded(
              child: _places.isEmpty && _suggestions.isEmpty && !_loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Выберите страну и введите минимум 2 буквы города',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: GlowColors.muted),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        ..._places.map((p) => _placeTile(p, elsewhere: false)),
                        if (_suggestions.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Text(
                              'Найдено в других странах',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: GlowColors.muted,
                              ),
                            ),
                          ),
                          ..._suggestions.map((p) => _placeTile(p, elsewhere: true)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
