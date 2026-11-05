import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/places.dart';
import '../data/profile_prefs_store.dart';
import '../l10n/app_locale.dart';
import 'widgets/city_picker_sheet.dart';
import 'widgets/custom_add_field.dart';
import 'widgets/language_toggle.dart';
import 'widgets/legal_links.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _prefs = ProfilePrefsStore();
  final _locale = AppLocale.instance;

  /// 0..2 intro, 3 cold, 4 heat, 5 activity, 6 age, 7 sex, 8 city,
  /// 9 habits, 10 allergies, 11 schedule, 12 skin
  int _page = 0;

  double _coldBias = 0;
  double _heatBias = 0;
  String _activity = 'moderate';
  String _ageBand = 'unknown';
  String _sex = 'unknown';
  final Set<String> _habits = {};
  final Set<String> _allergies = {};
  int _leaveHour = 8;
  int _returnHour = 19;
  PlaceOption _city = const PlaceOption(
    name: 'Москва',
    country: 'Россия',
    countryCode: 'RU',
    latitude: 55.7558,
    longitude: 37.6173,
  );
  String _skinNote = '';

  static const _lastPage = 12;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_refresh);
  }

  @override
  void dispose() {
    _locale.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    final existing = await _prefs.loadClimateProfile();
    // Fresh answers only — do not keep stale feedback from another account/cache.
    final profile = existing.copyWith(
      cityName: _city.name,
      cityCountry: _city.country,
      cityCountryCode: _city.countryCode,
      lat: _city.latitude,
      lon: _city.longitude,
      coldBias: _coldBias,
      heatBias: _heatBias,
      activity: _activity,
      ageBand: _ageBand,
      sex: _sex,
      habits: {..._habits},
      allergies: {..._allergies},
      leaveHour: _leaveHour,
      returnHour: _returnHour,
      skinNote: _skinNote,
      feedbackOffset: 0,
      feedbackCount: 0,
    );
    await _prefs.saveClimateProfile(profile);
    await _prefs.setOnboarded(true);
    widget.onDone();
  }

  Future<void> _pickCity() async {
    final picked = await showCityPickerSheet(
      context,
      title: _locale.t('today.pick.city'),
      selected: _city,
    );
    if (picked == null) return;
    setState(() => _city = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = _locale.t;
    final intro = <(String, String)>[
      (t('onboard.t1'), t('onboard.b1')),
      (t('onboard.t2'), t('onboard.b2')),
      (t('onboard.t3'), t('onboard.b3')),
    ];

    return Scaffold(
      backgroundColor: GlowColors.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(alignment: Alignment.centerRight, child: LanguageToggle()),
              const SizedBox(height: 16),
              Expanded(child: _page < 3 ? _buildIntro(intro) : _buildQuestion()),
              if (_page < 3)
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? GlowColors.sea : GlowColors.line,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (_page < _lastPage) {
                    setState(() => _page++);
                  } else {
                    await _finish();
                  }
                },
                child: Text(
                  _page >= _lastPage ? t('onboard.start') : t('onboard.next'),
                ),
              ),
              TextButton(
                onPressed: _finish,
                child: Text(t('onboard.skip')),
              ),
              const SizedBox(height: 8),
              const LegalLinks(compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(List<(String, String)> intro) {
    final current = intro[_page];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          current.$1,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: GlowColors.seaDeep,
          ),
        ),
        const SizedBox(height: 16),
        Text(current.$2, style: const TextStyle(fontSize: 16, height: 1.45)),
      ],
    );
  }

  Widget _multiChip({
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              FilterChip(
                label: Text(opt.$1),
                selected: selected.contains(opt.$2),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      selected.add(opt.$2);
                    } else {
                      selected.remove(opt.$2);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final t = _locale.t;
    switch (_page) {
      case 3:
        return _ChoiceBlock(
          title: t('onboard.q.cold'),
          options: [
            (t('onboard.q.no'), 0.0),
            (t('onboard.q.somewhat'), 0.7),
            (t('onboard.q.yes'), 1.4),
          ],
          selectedValue: _coldBias,
          onSelect: (v) => setState(() => _coldBias = v),
        );
      case 4:
        return _ChoiceBlock(
          title: t('onboard.q.heat'),
          options: [
            (t('onboard.q.no'), 0.0),
            (t('onboard.q.somewhat'), 0.7),
            (t('onboard.q.yes'), 1.4),
          ],
          selectedValue: _heatBias,
          onSelect: (v) => setState(() => _heatBias = v),
        );
      case 5:
        return _ChoiceBlock<String>(
          title: t('onboard.q.activity'),
          options: [
            (t('onboard.q.activity.low'), 'low'),
            (t('onboard.q.activity.mod'), 'moderate'),
            (t('onboard.q.activity.high'), 'high'),
          ],
          selectedValue: _activity,
          onSelect: (v) => setState(() => _activity = v),
        );
      case 6:
        return _ChoiceBlock<String>(
          title: t('onboard.q.age'),
          options: [
            (t('onboard.q.age.u30'), 'under_30'),
            (t('onboard.q.age.3050'), '30_50'),
            (t('onboard.q.age.o50'), 'over_50'),
            (t('onboard.q.age.skip'), 'unknown'),
          ],
          selectedValue: _ageBand,
          onSelect: (v) => setState(() => _ageBand = v),
        );
      case 7:
        return _ChoiceBlock<String>(
          title: t('onboard.q.sex'),
          options: [
            (t('onboard.q.sex.f'), 'female'),
            (t('onboard.q.sex.m'), 'male'),
            (t('onboard.q.sex.o'), 'other'),
            (t('onboard.q.sex.skip'), 'unknown'),
          ],
          selectedValue: _sex,
          onSelect: (v) => setState(() => _sex = v),
        );
      case 8:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('onboard.q.city'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(_city.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_city.country),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickCity,
            ),
          ],
        );
      case 9:
        return _multiChip(
          title: t('onboard.q.habits'),
          options: [
            (t('onboard.q.habits.walk'), 'walk'),
            (t('onboard.q.habits.sport'), 'sport'),
            (t('onboard.q.habits.bike'), 'bike'),
            (t('onboard.q.habits.office'), 'office_walk'),
          ],
          selected: _habits,
        );
      case 10:
        return _multiChip(
          title: t('onboard.q.allergies'),
          options: [
            (t('onboard.q.allergies.pollen'), 'pollen'),
            (t('onboard.q.allergies.sun'), 'sun'),
            (t('onboard.q.allergies.cold'), 'cold_skin'),
          ],
          selected: _allergies,
        );
      case 11:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('onboard.q.schedule'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text('${t('onboard.q.leave')}: $_leaveHour:00'),
            Slider(
              value: _leaveHour.toDouble(),
              min: 5,
              max: 12,
              divisions: 7,
              label: '$_leaveHour:00',
              onChanged: (v) => setState(() => _leaveHour = v.round()),
            ),
            Text('${t('onboard.q.return')}: $_returnHour:00'),
            Slider(
              value: _returnHour.toDouble(),
              min: 15,
              max: 23,
              divisions: 8,
              label: '$_returnHour:00',
              onChanged: (v) => setState(() => _returnHour = v.round()),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('onboard.q.skin'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(t('onboard.q.skin.hint'), style: const TextStyle(color: GlowColors.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in [
                  (t('onboard.q.skin.none'), ''),
                  (t('onboard.q.skin.dry'), 'dry'),
                  (t('onboard.q.skin.oily'), 'oily'),
                  (t('onboard.q.skin.combo'), 'combo'),
                  (t('onboard.q.skin.sensitive'), 'sensitive'),
                ])
                  ChoiceChip(
                    label: Text(opt.$1),
                    selected: _skinNote == opt.$2,
                    onSelected: (_) => setState(() => _skinNote = opt.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CustomAddField(
              hint: t('onboard.q.skin.custom'),
              onSubmit: (raw) {
                final cleaned = raw.trim();
                if (cleaned.isEmpty) return;
                setState(() => _skinNote = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned);
              },
            ),
          ],
        );
    }
  }
}

class _ChoiceBlock<T> extends StatelessWidget {
  const _ChoiceBlock({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
  });

  final String title;
  final List<(String, T)> options;
  final T selectedValue;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...options.map(
          (opt) {
            final selected = opt.$2 == selectedValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected ? GlowColors.foam : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(opt.$2),
                  child: ListTile(
                    title: Text(opt.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: GlowColors.sea)
                        : const Icon(Icons.circle_outlined, color: GlowColors.line),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
