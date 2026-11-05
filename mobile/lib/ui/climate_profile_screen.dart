import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/climate_api.dart';
import '../data/places.dart';
import '../data/profile_prefs_store.dart';
import '../l10n/app_locale.dart';
import 'widgets/city_picker_sheet.dart';

/// Edit climate onboarding answers after first run + show calibration progress.
class ClimateProfileScreen extends StatefulWidget {
  const ClimateProfileScreen({super.key});

  @override
  State<ClimateProfileScreen> createState() => _ClimateProfileScreenState();
}

class _ClimateProfileScreenState extends State<ClimateProfileScreen> {
  final _prefs = ProfilePrefsStore();
  final _api = ClimateApi();
  final _locale = AppLocale.instance;

  ClimateProfilePrefs _profile = const ClimateProfilePrefs();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _calibTarget = 25;

  String t(String k) => _locale.t(k);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final remote = await _api.getAccountProfile();
      await _prefs.applyAccountProfile(remote);
      final local = await _prefs.loadClimateProfile();
      if (!mounted) return;
      setState(() {
        _profile = local;
        _loading = false;
      });
    } catch (_) {
      final local = await _prefs.loadClimateProfile();
      if (!mounted) return;
      setState(() {
        _profile = local;
        _loading = false;
        _error = t('common.error');
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _prefs.toAccountProfile(_profile, onboarded: true);
      final saved = await _api.putAccountProfile(payload);
      await _prefs.applyAccountProfile(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('climate.profile.saved'))),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.error'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
    setState(() {
      _profile = _profile.copyWith(
        cityName: picked.name,
        cityCountry: picked.country,
        cityCountryCode: picked.countryCode,
        lat: picked.latitude,
        lon: picked.longitude,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _profile.feedbackCount;
    final progress = (count / _calibTarget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: Text(t('climate.profile.title')),
        backgroundColor: GlowColors.mist,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('common.done')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('climate.calib.title'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('climate.calib.progress')
                              .replaceAll('{n}', '$count')
                              .replaceAll('{t}', '$_calibTarget'),
                        ),
                        const SizedBox(height: 10),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(t('today.city')),
                  subtitle: Text('${_profile.cityName}, ${_profile.cityCountry}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _pickCity,
                ),
                const SizedBox(height: 12),
                _section(
                  t('onboard.q.cold'),
                  [
                    (t('onboard.q.no'), 0.0),
                    (t('onboard.q.somewhat'), 0.7),
                    (t('onboard.q.yes'), 1.4),
                  ],
                  _profile.coldBias,
                  (v) => setState(() => _profile = _profile.copyWith(coldBias: v)),
                ),
                _section(
                  t('onboard.q.heat'),
                  [
                    (t('onboard.q.no'), 0.0),
                    (t('onboard.q.somewhat'), 0.7),
                    (t('onboard.q.yes'), 1.4),
                  ],
                  _profile.heatBias,
                  (v) => setState(() => _profile = _profile.copyWith(heatBias: v)),
                ),
                _section<String>(
                  t('onboard.q.activity'),
                  [
                    (t('onboard.q.activity.low'), 'low'),
                    (t('onboard.q.activity.mod'), 'moderate'),
                    (t('onboard.q.activity.high'), 'high'),
                  ],
                  _profile.activity,
                  (v) => setState(() => _profile = _profile.copyWith(activity: v)),
                ),
                _section<String>(
                  t('onboard.q.age'),
                  [
                    (t('onboard.q.age.u30'), 'under_30'),
                    (t('onboard.q.age.3050'), '30_50'),
                    (t('onboard.q.age.o50'), 'over_50'),
                    (t('onboard.q.age.skip'), 'unknown'),
                  ],
                  _profile.ageBand,
                  (v) => setState(() => _profile = _profile.copyWith(ageBand: v)),
                ),
                _section<String>(
                  t('onboard.q.sex'),
                  [
                    (t('onboard.q.sex.f'), 'female'),
                    (t('onboard.q.sex.m'), 'male'),
                    (t('onboard.q.sex.o'), 'other'),
                    (t('onboard.q.sex.skip'), 'unknown'),
                  ],
                  _profile.sex,
                  (v) => setState(() => _profile = _profile.copyWith(sex: v)),
                ),
                _section<String>(
                  t('onboard.q.dress'),
                  [
                    (t('onboard.q.dress.lighter'), 'lighter'),
                    (t('onboard.q.dress.typical'), 'typical'),
                    (t('onboard.q.dress.warmer'), 'warmer'),
                  ],
                  _profile.dressBias,
                  (v) => setState(() => _profile = _profile.copyWith(dressBias: v)),
                ),
                _section<String>(
                  t('onboard.q.vignette'),
                  [
                    (t('onboard.q.vignette.cold'), 'cold'),
                    (t('onboard.q.vignette.ok'), 'ok'),
                    (t('onboard.q.vignette.warm'), 'warm'),
                    (t('onboard.q.acclimation.skip'), 'unknown'),
                  ],
                  _profile.vignetteSensation,
                  (v) => setState(() => _profile = _profile.copyWith(vignetteSensation: v)),
                ),
                _section<String>(
                  t('onboard.q.acclimation'),
                  [
                    (t('onboard.q.acclimation.long'), 'long'),
                    (t('onboard.q.acclimation.recent'), 'recent'),
                    (t('onboard.q.acclimation.temporary'), 'temporary'),
                    (t('onboard.q.acclimation.skip'), 'unknown'),
                  ],
                  _profile.acclimation,
                  (v) => setState(() => _profile = _profile.copyWith(acclimation: v)),
                ),
                const SizedBox(height: 8),
                Text(t('onboard.q.schedule'), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${t('onboard.q.leave')}: ${_profile.leaveHour}:00'),
                Slider(
                  value: _profile.leaveHour.toDouble(),
                  min: 5,
                  max: 12,
                  divisions: 7,
                  label: '${_profile.leaveHour}:00',
                  onChanged: (v) => setState(
                    () => _profile = _profile.copyWith(leaveHour: v.round()),
                  ),
                ),
                Text('${t('onboard.q.return')}: ${_profile.returnHour}:00'),
                Slider(
                  value: _profile.returnHour.toDouble(),
                  min: 15,
                  max: 23,
                  divisions: 8,
                  label: '${_profile.returnHour}:00',
                  onChanged: (v) => setState(
                    () => _profile = _profile.copyWith(returnHour: v.round()),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section<T>(
    String title,
    List<(String, T)> options,
    T selected,
    ValueChanged<T> onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in options)
                ChoiceChip(
                  label: Text(opt.$1),
                  selected: opt.$2 == selected,
                  onSelected: (_) => onSelect(opt.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
