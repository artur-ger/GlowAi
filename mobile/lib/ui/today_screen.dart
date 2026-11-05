import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/climate_api.dart';
import '../data/climate_models.dart';
import '../data/climate_reminders.dart';
import '../data/places.dart';
import '../data/profile_prefs_store.dart';
import '../l10n/app_locale.dart';
import 'climate_profile_screen.dart';
import 'widgets/city_picker_sheet.dart';
import 'widgets/custom_add_field.dart';
import 'widgets/language_toggle.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  final _prefs = ProfilePrefsStore();
  final _api = ClimateApi();
  final _locale = AppLocale.instance;
  final _reminders = ClimateReminders();
  final _planCtrl = TextEditingController();

  ClimateProfilePrefs _profile = const ClimateProfilePrefs();
  ClimateTodayResult? _today;
  bool _loading = true;
  String? _error;
  String _wornTier = 'as_advised';
  String _lookPreserved = 'na';
  String _moment = 'anytime';
  String? _planSummary;
  bool _planBusy = false;
  bool _remindersEnabled = false;
  static const _calibTarget = 25;

  String t(String key) => _locale.t(key);

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocale);
    _bootstrap();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocale);
    _planCtrl.dispose();
    super.dispose();
  }

  void _onLocale() {
    if (mounted) {
      setState(() {});
      _reload();
    }
  }

  Future<void> _bootstrap() async {
    final profile = await _prefs.loadClimateProfile();
    final remindOn = await _reminders.isEnabled();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _remindersEnabled = remindOn;
    });
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.today(
        city: _profile.cityName,
        lat: _profile.lat,
        lon: _profile.lon,
        profile: _profile.toPayload(),
        clientKey: _profile.clientKey,
        lang: _locale.code,
      );
      if (!mounted) return;
      setState(() {
        _today = result;
        _loading = false;
        if (result.feedbackWindow != null) {
          _moment = result.feedbackWindow!.moment;
        }
      });
      final fw = result.feedbackWindow;
      if (fw != null && (fw.moment == 'leave' || fw.moment == 'return')) {
        await _reminders.maybeNotify(
          moment: fw.moment,
          title: fw.moment == 'leave' ? t('today.moment.leave') : t('today.moment.return'),
          body: fw.prompt,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final detail = e.toString();
      setState(() {
        _loading = false;
        _error = detail.contains('404')
            ? '${t('common.error')} (API /climate/today недоступен — перезапусти backend)'
            : t('common.error');
        _today = null;
      });
    }
  }

  Future<void> _pickCity() async {
    final picked = await showCityPickerSheet(
      context,
      title: t('today.pick.city'),
      selected: PlaceOption(
        name: _profile.cityName,
        country: _profile.cityCountry,
        countryCode: _profile.cityCountryCode,
        latitude: _profile.lat,
        longitude: _profile.lon,
      ),
    );
    if (picked == null) return;
    final next = _profile.copyWith(
      cityName: picked.name,
      cityCountry: picked.country,
      cityCountryCode: picked.countryCode,
      lat: picked.latitude,
      lon: picked.longitude,
    );
    await _prefs.saveClimateProfile(next);
    if (!mounted) return;
    setState(() => _profile = next);
    await _reload();
  }

  Future<void> _addCustom(
    Set<String> Function(ClimateProfilePrefs) read,
    ClimateProfilePrefs Function(Set<String>) write,
    String raw,
  ) async {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    final text = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
    final nextSet = {...read(_profile), text};
    final next = write(nextSet);
    await _prefs.saveClimateProfile(next);
    if (!mounted) return;
    setState(() => _profile = next);
  }

  Future<void> _removeCustom(bool clothing, String value) async {
    final next = clothing
        ? _profile.copyWith(
            customClothing: {..._profile.customClothing}..remove(value),
          )
        : _profile.copyWith(
            customCare: {..._profile.customCare}..remove(value),
          );
    await _prefs.saveClimateProfile(next);
    if (!mounted) return;
    setState(() => _profile = next);
  }

  Future<void> _sendFeedback(int actual) async {
    final predicted = _today?.sensation ?? 0;
    try {
      final res = await _api.feedback(
        city: _profile.cityName,
        lat: _profile.lat,
        lon: _profile.lon,
        predictedSensation: predicted,
        actualSensation: actual,
        wornTier: _wornTier,
        lookPreserved: _lookPreserved,
        moment: _moment,
        predictedUtciC: _today?.personalUtciC,
        clientKey: _profile.clientKey,
      );
      final offset = (res.feedbackOffset ??
              (_profile.feedbackOffset + res.suggestedFeedbackOffsetDelta))
          .clamp(-5.0, 5.0)
          .toDouble();
      final count = res.feedbackCount > 0 ? res.feedbackCount : _profile.feedbackCount + 1;
      final next = _profile.copyWith(
        feedbackOffset: offset,
        feedbackCount: count,
      );
      await _prefs.saveClimateProfile(next);
      // Keep server copy in sync (auth feedback already wrote offset; still upsert rest).
      try {
        await _api.putAccountProfile(
          _prefs.toAccountProfile(next, onboarded: true),
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _profile = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('climate.calib.after'))),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.error'))),
      );
    }
  }

  Future<void> _runPlan() async {
    final text = _planCtrl.text.trim();
    if (text.length < 3) return;
    setState(() => _planBusy = true);
    try {
      final res = await _api.plan(
        text: text,
        city: _profile.cityName,
        lat: _profile.lat,
        lon: _profile.lon,
        profile: _profile.toPayload(),
        clientKey: _profile.clientKey,
        lang: _locale.code,
      );
      if (!mounted) return;
      setState(() {
        _today = res.today;
        _planSummary = res.summary;
        _planBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _planBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F2), GlowColors.mist, Color(0xFFF7FAF9)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageToggle(),
                ),
                const SizedBox(height: 8),
                Text(
                  t('today.title'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: GlowColors.seaDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('today.slogan'),
                  style: const TextStyle(color: GlowColors.muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _pickCity,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, color: GlowColors.sea),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('today.city'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: GlowColors.muted,
                                  ),
                                ),
                                Text(
                                  '${_profile.cityName}, ${_profile.cityCountry}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: GlowColors.muted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error!, onRetry: _reload)
                else if (_today != null)
                  ..._buildTodayBody(_today!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTodayBody(ClimateTodayResult today) {
    final count = _profile.feedbackCount;
    final progress = (count / _calibTarget).clamp(0.0, 1.0);
    return [
      _SensationCard(today: today, t: t),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('climate.calib.title'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('climate.calib.progress')
                  .replaceAll('{n}', '$count')
                  .replaceAll('{t}', '$_calibTarget'),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              count >= 3
                  ? t('climate.calib.active')
                      .replaceAll('{off}', _profile.feedbackOffset.toStringAsFixed(2))
                  : t('climate.calib.starter'),
              style: const TextStyle(color: GlowColors.muted, height: 1.35),
            ),
            TextButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ClimateProfileScreen()),
                );
                if (changed == true) await _bootstrap();
              },
              child: Text(t('climate.profile.open')),
            ),
          ],
        ),
      ),
      if (today.feedbackWindow != null && today.feedbackWindow!.moment != 'anytime') ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: today.feedbackWindow!.moment == 'leave'
              ? t('today.moment.leave')
              : t('today.moment.return'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(today.feedbackWindow!.prompt),
              const SizedBox(height: 8),
              if (!_remindersEnabled)
                OutlinedButton(
                  onPressed: () async {
                    final ok = await _reminders.enableWithPermission();
                    if (!mounted) return;
                    setState(() => _remindersEnabled = ok);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? t('today.remind.enabled') : t('common.error')),
                      ),
                    );
                    if (ok) {
                      await _reminders.maybeNotify(
                        moment: today.feedbackWindow!.moment,
                        title: today.feedbackWindow!.moment == 'leave'
                            ? t('today.moment.leave')
                            : t('today.moment.return'),
                        body: today.feedbackWindow!.prompt,
                      );
                    }
                  },
                  child: Text(t('today.remind.enable')),
                )
              else
                Text(
                  t('today.remind.enabled'),
                  style: const TextStyle(color: GlowColors.muted, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
      if (today.explanation.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: t('today.explain'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(today.explanation, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 8),
              Text(
                today.llmUsed ? t('today.llm.llm') : t('today.llm.rules'),
                style: const TextStyle(fontSize: 12, color: GlowColors.muted),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.pet.compare'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UTCI ${today.utciC.toStringAsFixed(1)}° · personal ${today.personalUtciC.toStringAsFixed(1)}°'),
            if (today.support.petC != null)
              Text('PET ${today.support.petC!.toStringAsFixed(1)}°'),
            Text(
              today.sensationLabel,
              style: const TextStyle(color: GlowColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.support'),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('${t('today.ireq')} ${today.support.ireqClo.toStringAsFixed(2)}')),
            if (today.support.petC != null)
              Chip(label: Text('${t('today.pet')} ${today.support.petC!.toStringAsFixed(1)}°')),
            if (today.support.windChillC != null)
              Chip(label: Text('WC ${today.support.windChillC!.toStringAsFixed(1)}°')),
            if (today.support.heatIndexC != null)
              Chip(label: Text('HI ${today.support.heatIndexC!.toStringAsFixed(1)}°')),
            if (today.support.humidexC != null)
              Chip(label: Text('Hx ${today.support.humidexC!.toStringAsFixed(1)}')),
          ],
        ),
      ),
      if (today.spareLayer) ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: t('today.spare'),
          child: Text(today.spareLayerNote, style: const TextStyle(height: 1.35)),
        ),
      ],
      if (today.hours.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: t('today.hours'),
          child: SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: today.hours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final h = today.hours[i];
                return Container(
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlowColors.foam,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h.hourLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${h.utciC.toStringAsFixed(0)}°',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        h.sensationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: GlowColors.muted),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.plan'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _planCtrl,
              decoration: InputDecoration(
                hintText: t('today.plan.hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _planBusy ? null : _runPlan,
              child: _planBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('today.plan.run')),
            ),
            if (_planSummary != null) ...[
              const SizedBox(height: 8),
              Text(_planSummary!, style: const TextStyle(color: GlowColors.muted)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.dress'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...today.clothing.map(
              (c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.checkroom, color: GlowColors.sea),
                title: Text(c.item, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.clo != null ? '${c.layer} · clo ${c.clo}' : c.layer),
              ),
            ),
            if (_profile.customClothing.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _profile.customClothing
                    .map(
                      (c) => InputChip(
                        label: Text(c),
                        onDeleted: () => _removeCustom(true, c),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            CustomAddField(
              hint: t('today.custom.dress.hint'),
              onSubmit: (raw) => _addCustom(
                (p) => p.customClothing,
                (set) => _profile.copyWith(customClothing: set),
                raw,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.care'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...today.care.map(
              (c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.spa_outlined, color: GlowColors.coral),
                title: Text(c.item, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.reason),
              ),
            ),
            if (_profile.customCare.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _profile.customCare
                    .map(
                      (c) => InputChip(
                        label: Text(c),
                        onDeleted: () => _removeCustom(false, c),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            CustomAddField(
              hint: t('today.custom.care.hint'),
              accent: GlowColors.coral,
              onSubmit: (raw) => _addCustom(
                (p) => p.customCare,
                (set) => _profile.copyWith(customCare: set),
                raw,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.look'),
        child: Text(
          '${t('today.look.risk')}: ${today.appearanceRisk}/3 — ${today.appearanceNote}',
          style: const TextStyle(height: 1.35),
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: t('today.why'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: today.why
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('· $w'),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      Text(t('today.worn'), style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final opt in [
            ('lighter', t('today.worn.lighter')),
            ('as_advised', t('today.worn.as')),
            ('warmer', t('today.worn.warmer')),
          ])
            ChoiceChip(
              label: Text(opt.$2),
              selected: _wornTier == opt.$1,
              onSelected: (_) => setState(() => _wornTier = opt.$1),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(t('today.look.fb'), style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final opt in [
            ('yes', t('today.look.yes')),
            ('no', t('today.look.no')),
            ('na', t('today.look.na')),
          ])
            ChoiceChip(
              label: Text(opt.$2),
              selected: _lookPreserved == opt.$1,
              onSelected: (_) => setState(() => _lookPreserved = opt.$1),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(t('today.feedback'), style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final opt in [
            ('leave', t('today.moment.leave')),
            ('return', t('today.moment.return')),
            ('anytime', t('today.moment.any')),
          ])
            ChoiceChip(
              label: Text(opt.$2),
              selected: _moment == opt.$1,
              onSelected: (_) => setState(() => _moment = opt.$1),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in [-2, -1, 0, 1, 2])
            ActionChip(
              label: Text(_shortLabel(s)),
              onPressed: () => _sendFeedback(s),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        today.disclaimer,
        style: const TextStyle(fontSize: 12, color: GlowColors.muted, height: 1.35),
      ),
    ];
  }

  String _shortLabel(int s) {
    switch (s) {
      case -2:
        return t('today.fb.cold');
      case -1:
        return t('today.fb.cool');
      case 0:
        return t('today.fb.ok');
      case 1:
        return t('today.fb.warm');
      default:
        return t('today.fb.hot');
    }
  }
}

class _SensationCard extends StatelessWidget {
  const _SensationCard({required this.today, required this.t});

  final ClimateTodayResult today;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GlowColors.seaDeep,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            today.sensationLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            today.calibrationNote,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: '${t('today.utci')} ${today.utciC.toStringAsFixed(1)}°',
              ),
              _MetricChip(
                label:
                    '${t('today.personal')} ${today.personalUtciC.toStringAsFixed(1)}°',
              ),
              if (today.tempC != null)
                _MetricChip(label: '${today.tempC!.toStringAsFixed(0)}°C'),
              if (today.windMs != null)
                _MetricChip(label: '${t('today.wind')} ${today.windMs!.toStringAsFixed(1)}'),
              if (today.uv != null) _MetricChip(label: 'UV ${today.uv!.toStringAsFixed(0)}'),
              _MetricChip(label: '${t('today.confidence')}: ${today.confidence}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        children: [
          Text(message),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
