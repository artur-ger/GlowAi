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

  /// 0..2 intro, then mode (3), then question indices into [_flow].
  int _page = 0;
  bool _quickMode = true;
  int _flowIndex = 0;

  double _coldBias = 0;
  double _heatBias = 0;
  String _activity = 'moderate';
  String _ageBand = 'unknown';
  String _sex = 'unknown';
  String _dressBias = 'typical';
  String _acclimation = 'unknown';
  String _vignetteSensation = 'unknown';
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

  /// Question ids: 3 cold, 4 heat, 5 activity, 6 age, 7 sex, 8 city,
  /// 9 habits, 10 allergies, 11 schedule, 12 skin, 13 dress, 14 vignette, 15 acclimation
  static const _quickFlow = [3, 4, 5, 8, 13];
  static const _fullFlow = [3, 4, 5, 13, 8, 6, 7, 14, 15, 9, 10, 11, 12];
  static const _detailExtra = [6, 7, 14, 15, 9, 10, 11, 12];

  List<int> get _flow {
    if (_quickMode) {
      // After finishing quick core, optional details may append.
      if (_flowIndex >= _quickFlow.length) {
        return [..._quickFlow, ..._detailExtra];
      }
      return _quickFlow;
    }
    return _fullFlow;
  }

  bool get _inIntro => _page < 3;
  bool get _inMode => _page == 3;
  bool get _inQuestions => _page >= 4;

  int get _questionId => _flow[_flowIndex.clamp(0, _flow.length - 1)];

  bool get _atLastQuestion => _flowIndex >= _flow.length - 1;

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
      dressBias: _dressBias,
      acclimation: _acclimation,
      vignetteSensation: _vignetteSensation,
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

  void _next() {
    if (_inIntro) {
      setState(() => _page++);
      return;
    }
    if (_inMode) {
      setState(() {
        _page = 4;
        _flowIndex = 0;
      });
      return;
    }
    if (!_atLastQuestion) {
      setState(() => _flowIndex++);
      return;
    }
    _finish();
  }

  Future<void> _openOptionalDetails() async {
    setState(() {
      // Jump past quick core into optional extras while staying in quick mode.
      _flowIndex = _quickFlow.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _locale.t;
    final intro = <(String, String)>[
      (t('onboard.t1'), t('onboard.b1')),
      (t('onboard.t2'), t('onboard.b2')),
      (t('onboard.t3'), t('onboard.b3')),
    ];

    final showOptionalDetails =
        _inQuestions && _quickMode && _flowIndex == _quickFlow.length - 1;

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
              Expanded(
                child: _inIntro
                    ? _buildIntro(intro)
                    : _inMode
                        ? _buildMode()
                        : _buildQuestion(),
              ),
              if (_inIntro)
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
              if (_inQuestions) ...[
                Text(
                  '${_flowIndex + 1} / ${_flow.length}',
                  style: const TextStyle(color: GlowColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              if (showOptionalDetails)
                TextButton(
                  onPressed: _openOptionalDetails,
                  child: Text(t('onboard.details')),
                ),
              FilledButton(
                onPressed: () async {
                  if (_inQuestions && _atLastQuestion) {
                    await _finish();
                  } else {
                    _next();
                  }
                },
                child: Text(
                  (_inQuestions && _atLastQuestion) ? t('onboard.start') : t('onboard.next'),
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

  Widget _buildMode() {
    final t = _locale.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('onboard.mode.quick'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _ModeTile(
          title: t('onboard.mode.quick'),
          selected: _quickMode,
          onTap: () => setState(() => _quickMode = true),
        ),
        const SizedBox(height: 8),
        _ModeTile(
          title: t('onboard.mode.full'),
          selected: !_quickMode,
          onTap: () => setState(() => _quickMode = false),
        ),
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
    switch (_questionId) {
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
      case 13:
        return _ChoiceBlock<String>(
          title: t('onboard.q.dress'),
          options: [
            (t('onboard.q.dress.lighter'), 'lighter'),
            (t('onboard.q.dress.typical'), 'typical'),
            (t('onboard.q.dress.warmer'), 'warmer'),
          ],
          selectedValue: _dressBias,
          onSelect: (v) => setState(() => _dressBias = v),
        );
      case 14:
        return _ChoiceBlock<String>(
          title: t('onboard.q.vignette'),
          options: [
            (t('onboard.q.vignette.cold'), 'cold'),
            (t('onboard.q.vignette.ok'), 'ok'),
            (t('onboard.q.vignette.warm'), 'warm'),
            (t('onboard.q.acclimation.skip'), 'unknown'),
          ],
          selectedValue: _vignetteSensation,
          onSelect: (v) => setState(() => _vignetteSensation = v),
        );
      case 15:
        return _ChoiceBlock<String>(
          title: t('onboard.q.acclimation'),
          options: [
            (t('onboard.q.acclimation.long'), 'long'),
            (t('onboard.q.acclimation.recent'), 'recent'),
            (t('onboard.q.acclimation.temporary'), 'temporary'),
            (t('onboard.q.acclimation.skip'), 'unknown'),
          ],
          selectedValue: _acclimation,
          onSelect: (v) => setState(() => _acclimation = v),
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GlowColors.foam : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: selected
              ? const Icon(Icons.check_circle, color: GlowColors.sea)
              : const Icon(Icons.circle_outlined, color: GlowColors.line),
        ),
      ),
    );
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
