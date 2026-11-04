import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/analyze_api.dart';
import '../data/auth_store.dart';
import '../data/follow_up_bridge.dart';
import '../data/places.dart';
import '../data/profile_api.dart';
import '../data/profile_prefs_store.dart';
import '../data/session_store.dart';
import '../data/trips_api.dart';
import '../l10n/app_locale.dart';
import '../l10n/catalog.dart';
import 'analyzing_screen.dart';
import 'result_screen.dart';
import 'widgets/active_trip_card.dart';
import 'widgets/city_picker_sheet.dart';
import 'widgets/custom_add_field.dart';
import 'widgets/language_toggle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _api = AnalyzeApi();
  final _picker = ImagePicker();
  final _store = SessionStore();
  final _prefs = ProfilePrefsStore();
  final _authStore = AuthStore();
  final _profileApi = ProfileApi();
  final _tripsApi = TripsApi();

  final _locale = AppLocale.instance;

  PlaceOption _home = defaultHome;
  PlaceOption _destination = defaultDestination;
  String _skinType = 'combo';
  final Set<String> _concerns = {'dryness', 'irritation'};
  final Set<String> _owned = {'spf', 'cleanser'};
  final Set<String> _avoid = {'acids'};
  String _mode = 'pre_trip';
  DateTime _tripStart = DateTime.now().add(const Duration(days: 7));
  DateTime _tripEnd = DateTime.now().add(const Duration(days: 14));
  XFile? _photo;
  bool _photoConsent = false;
  bool _loading = false;
  String? _error;
  SavedSession? _saved;
  int? _parentCheckId;
  TripItem? _activeTrip;
  DailyTip? _dailyTip;
  bool _tipLoading = false;

  String t(String key) => _locale.t(key);

  void consumeFollowUpBridge() {
    final pending = FollowUpBridge.take();
    if (pending == null) return;
    setState(() {
      _parentCheckId = pending.parentId;
      _mode = 'sos';
      _photo = null;
      _photoConsent = false;
      _error = null;
      if (pending.home.isNotEmpty) {
        _home = PlaceOption(
          name: pending.home,
          countryCode: _home.countryCode,
          country: _home.country,
          latitude: _home.latitude,
          longitude: _home.longitude,
        );
      }
      if (pending.dest.isNotEmpty) {
        _destination = PlaceOption(
          name: pending.dest,
          countryCode: _destination.countryCode,
          country: _destination.country,
          latitude: _destination.latitude,
          longitude: _destination.longitude,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('home.sos.bridge'))),
    );
  }

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocale);
    _loadSaved();
    _loadMemory();
    _loadActiveTrip();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  void _addCustomText(Set<String> target, String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    final text = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
    setState(() => target.add(text));
  }

  Widget _customChipField({
    required Set<String> target,
    required String hint,
    Color accent = GlowColors.sea,
  }) {
    return CustomAddField(
      hint: hint,
      enabled: !_loading,
      accent: accent,
      onSubmit: (raw) => _addCustomText(target, raw),
    );
  }

  Future<void> _loadSaved() async {
    final saved = await _store.load();
    if (!mounted || saved == null) return;
    setState(() => _saved = saved);
  }

  Future<void> _loadMemory() async {
    final local = await _prefs.loadFormMemory();
    if (local != null && mounted) {
      setState(() {
        final skinIds = normalizeIds({local.skinType}, skinTypeOptions);
        if (skinIds.isNotEmpty) _skinType = skinIds.first;
        _concerns
          ..clear()
          ..addAll(normalizeIds(local.concerns, concernChipOptions));
        _owned
          ..clear()
          ..addAll(normalizeIds(local.owned, ownedChipOptions));
        _avoid
          ..clear()
          ..addAll(normalizeIds(local.avoid, avoidChipOptions));
      });
    }
    if (!await _authStore.isLoggedIn) return;
    try {
      final p = await _profileApi.me();
      if (!mounted) return;
      setState(() {
        if (p.skinType.isNotEmpty) {
          final skinIds = normalizeIds({p.skinType}, skinTypeOptions);
          if (skinIds.isNotEmpty) _skinType = skinIds.first;
        }
        if (p.concerns.isNotEmpty) {
          _concerns
            ..clear()
            ..addAll(normalizeIds(p.concerns.toSet(), concernChipOptions));
        }
        if (p.ownedItems.isNotEmpty) {
          _owned
            ..clear()
            ..addAll(normalizeIds(p.ownedItems.toSet(), ownedChipOptions));
        }
        if (p.avoidItems.isNotEmpty) {
          _avoid
            ..clear()
            ..addAll(normalizeIds(p.avoidItems.toSet(), avoidChipOptions));
        }
      });
    } catch (_) {}
  }

  Future<void> _loadActiveTrip() async {
    if (!await _authStore.isLoggedIn) return;
    try {
      final trip = await _tripsApi.activeTrip();
      if (!mounted) return;
      setState(() => _activeTrip = trip);
      if (trip != null && (trip.status == 'on_site' || trip.status == 'return_home')) {
        await _refreshTip();
      }
    } catch (_) {}
  }

  Future<void> _refreshTip() async {
    final trip = _activeTrip;
    if (trip == null) return;
    setState(() => _tipLoading = true);
    try {
      final tip = await _tripsApi.dailyTip(trip.id);
      if (!mounted) return;
      setState(() {
        _dailyTip = tip;
        _tipLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _tipLoading = false);
    }
  }

  Future<void> _setTripStatus(String status) async {
    final trip = _activeTrip;
    if (trip == null) return;
    try {
      final updated = await _tripsApi.setStatus(trip.id, status);
      if (!mounted) return;
      setState(() {
        _activeTrip = updated.isActive ? updated : null;
        if (status == 'return_home') _mode = 'return_home';
        if (status == 'on_site') _mode = 'sos';
        if (status == 'pre_trip') _mode = 'pre_trip';
      });
      if (status == 'on_site' || status == 'return_home') await _refreshTip();
    } catch (_) {}
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _tripStart : _tripEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: start ? 'Начало поездки' : 'Конец поездки',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _tripStart = picked;
        if (_tripEnd.isBefore(_tripStart)) {
          _tripEnd = _tripStart.add(const Duration(days: 3));
        }
      } else {
        _tripEnd = picked.isBefore(_tripStart) ? _tripStart : picked;
      }
    });
  }

  Future<void> _pickCity({required bool home}) async {
    final picked = await showCityPickerSheet(
      context,
      title: home ? t('home.pick.home') : t('home.pick.dest'),
      selected: home ? _home : _destination,
    );
    if (picked == null) return;
    setState(() {
      if (home) {
        _home = picked;
      } else {
        _destination = picked;
      }
    });
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photo = file);
  }

  Future<void> _showPhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GlowColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('home.photo.camera')),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('home.photo.gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(source: ImageSource.gallery);
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: GlowColors.coral),
                title: Text(t('home.photo.remove'), style: const TextStyle(color: GlowColors.coral)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photo = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSavedResult() async {
    final saved = _saved;
    if (saved == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: saved.result,
          onFollowUp: () {
            Navigator.of(context).pop();
            _startFollowUp();
          },
        ),
      ),
    );
  }

  void _startFollowUp({int? parentCheckId}) {
    final saved = _saved;
    if (saved == null && parentCheckId == null) return;
    setState(() {
      if (saved != null) {
        _home = saved.home;
        _destination = saved.destination;
        _skinType = saved.skinType.isNotEmpty ? saved.skinType : _skinType;
        _concerns
          ..clear()
          ..addAll(saved.concerns);
      }
      _parentCheckId = parentCheckId ?? _parentCheckId;
      _mode = 'sos';
      _photo = null;
      _photoConsent = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_home.name == _destination.name &&
        _home.countryCode == _destination.countryCode) {
      setState(() => _error = 'Выберите разные города: дом и направление поездки.');
      return;
    }
    if (_photo != null && !_photoConsent) {
      setState(() => _error = t('home.photo.consent.needed'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AnalyzingScreen(destination: _destination.name),
      ),
    );
    try {
      final skinApi = skinApiValue(_skinType);
      final concernsApi = labelsForApi(_concerns, concernChipOptions);
      final ownedApi = labelsForApi(_owned, ownedChipOptions);
      final avoidApi = labelsForApi(_avoid, avoidChipOptions);
      await _prefs.saveFormMemory(
        skinType: _skinType,
        concerns: _concerns,
        owned: _owned,
        avoid: _avoid,
      );
      if (await _authStore.isLoggedIn) {
        try {
          await _profileApi.patch(
            skinType: skinApi,
            concerns: concernsApi.split(', ').where((e) => e.isNotEmpty).toList(),
            ownedItems: ownedApi.split(', ').where((e) => e.isNotEmpty).toList(),
            avoidItems: avoidApi.split(', ').where((e) => e.isNotEmpty).toList(),
          );
        } catch (_) {}
      }
      final photoToSend = (_photo != null && _photoConsent) ? _photo : null;
      final result = await _api.analyze(
        homeCity: _home.name,
        destinationCity: _destination.name,
        skinType: skinApi,
        concerns: concernsApi,
        mode: _mode,
        tripStart: _mode == 'pre_trip' ? _fmt(_tripStart) : '',
        tripEnd: _mode == 'pre_trip' ? _fmt(_tripEnd) : '',
        ownedItems: ownedApi,
        avoidItems: avoidApi,
        homeLat: _home.latitude,
        homeLon: _home.longitude,
        destLat: _destination.latitude,
        destLon: _destination.longitude,
        photo: photoToSend,
      );
      if (!mounted) return;
      await _store.save(
        result: result,
        home: _home,
        destination: _destination,
        skinType: _skinType,
        concerns: _concerns,
      );
      if (!mounted) return;
      setState(() => _saved = SavedSession(
            savedAt: DateTime.now(),
            home: _home,
            destination: _destination,
            skinType: _skinType,
            concerns: Set<String>.from(_concerns),
            result: result,
          ));
      final nav = Navigator.of(context);
      nav.pop(); // close analyzing
      await nav.push(
        MaterialPageRoute(
          builder: (ctx) => ResultScreen(
            result: result,
            parentCheckId: _mode == 'sos' ? _parentCheckId : null,
            onFollowUp: () {
              Navigator.of(ctx).pop();
              _startFollowUp(parentCheckId: _parentCheckId);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // close analyzing
        setState(() => _error = 'Не удалось получить план. Проверьте, что API запущен.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No nested Scaffold — ShellScreen owns chrome / bottom nav.
    // SizedBox.expand: fill Shell body so NavigationBar stays visible.
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: LanguageToggle(),
              ),
              const SizedBox(height: 8),
              _HeroHeader(mode: _mode, subtitle: t('home.subtitle')),
              const SizedBox(height: 10),
              _MvpHint(text: t('disclaimer')),
              if (_activeTrip != null) ...[
                const SizedBox(height: 12),
                ActiveTripCard(
                  trip: _activeTrip!,
                  tip: _dailyTip,
                  loadingTip: _tipLoading,
                  onStatus: _setTripStatus,
                  onRefreshTip: _refreshTip,
                ),
              ],
              if (_saved != null) ...[
                const SizedBox(height: 12),
                _FollowUpBanner(
                  destination: _saved!.destination.name,
                  savedAt: _saved!.savedAt,
                  onOpen: _openSavedResult,
                  onRepeat: _startFollowUp,
                  lastLabel: t('home.last'),
                  openLabel: t('home.open'),
                ),
              ],
              const SizedBox(height: 18),
              _ModeToggle(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
                preLabel: t('home.mode.pre'),
                sosLabel: t('home.mode.sos'),
                returnLabel: t('home.mode.return'),
              ),
              const SizedBox(height: 18),
              _SectionLabel(text: t('home.from'), step: '1'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CityTile(
                      caption: _mode == 'return_home' ? t('home.home') : t('home.from'),
                      city: _home,
                      onTap: () => _pickCity(home: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.flight_takeoff_rounded, color: GlowColors.sea),
                  ),
                  Expanded(
                    child: _CityTile(
                      caption: _mode == 'return_home' ? t('home.were') : t('home.to'),
                      city: _destination,
                      onTap: () => _pickCity(home: false),
                    ),
                  ),
                ],
              ),
              if (_mode == 'pre_trip') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DateTile(
                        caption: t('home.depart'),
                        value: _fmt(_tripStart),
                        onTap: () => _pickDate(start: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTile(
                        caption: t('home.return'),
                        value: _fmt(_tripEnd),
                        onTap: () => _pickDate(start: false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _SectionLabel(text: t('home.skin'), step: '2'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skinTypeOptions.map((opt) {
                  final selected = _skinType == opt.id;
                  return ChoiceChip(
                    label: Text(opt.label(_locale.code)),
                    selected: selected,
                    onSelected: (_) => setState(() => _skinType = opt.id),
                    selectedColor: GlowColors.sea,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : GlowColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: selected ? GlowColors.sea : GlowColors.line),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: t('home.concerns'), step: '3'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...concernChipOptions.map((opt) {
                    final selected = _concerns.contains(opt.id);
                    return FilterChip(
                      label: Text(opt.label(_locale.code)),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _concerns.add(opt.id);
                          } else {
                            _concerns.remove(opt.id);
                          }
                        });
                      },
                      selectedColor: GlowColors.foam,
                      checkmarkColor: GlowColors.seaDeep,
                      labelStyle: TextStyle(
                        color: GlowColors.ink,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? GlowColors.sea : GlowColors.line,
                      ),
                    );
                  }),
                  ..._concerns
                      .where((c) => !concernChipOptions.any((o) => o.id == c))
                      .map(
                        (c) => FilterChip(
                          label: Text(c),
                          selected: true,
                          onSelected: (_) => setState(() => _concerns.remove(c)),
                          selectedColor: GlowColors.foam,
                          checkmarkColor: GlowColors.seaDeep,
                          labelStyle: const TextStyle(
                            color: GlowColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: GlowColors.sea),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              _customChipField(
                target: _concerns,
                hint: t('home.custom.concern.hint'),
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: t('home.owned'), step: '4'),
              const SizedBox(height: 8),
              Text(
                t('home.owned.hint'),
                style: const TextStyle(color: GlowColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...ownedChipOptions.map((opt) {
                    final selected = _owned.contains(opt.id);
                    return FilterChip(
                      label: Text(opt.label(_locale.code)),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _owned.add(opt.id);
                        } else {
                          _owned.remove(opt.id);
                        }
                      }),
                      selectedColor: GlowColors.foam,
                      checkmarkColor: GlowColors.seaDeep,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: selected ? GlowColors.sea : GlowColors.line),
                    );
                  }),
                  ..._owned.where((c) => !ownedChipOptions.any((o) => o.id == c)).map(
                        (c) => FilterChip(
                          label: Text(c),
                          selected: true,
                          onSelected: (_) => setState(() => _owned.remove(c)),
                          selectedColor: GlowColors.foam,
                          checkmarkColor: GlowColors.seaDeep,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: GlowColors.sea),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              _customChipField(
                target: _owned,
                hint: t('home.custom.owned.hint'),
              ),
              const SizedBox(height: 18),
              _SectionLabel(text: t('home.avoid'), step: '5'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...avoidChipOptions.map((opt) {
                    final selected = _avoid.contains(opt.id);
                    return FilterChip(
                      label: Text(opt.label(_locale.code)),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _avoid.add(opt.id);
                        } else {
                          _avoid.remove(opt.id);
                        }
                      }),
                      selectedColor: const Color(0xFFFFE8E4),
                      checkmarkColor: GlowColors.coral,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: selected ? GlowColors.coral : GlowColors.line),
                    );
                  }),
                  ..._avoid.where((c) => !avoidChipOptions.any((o) => o.id == c)).map(
                        (c) => FilterChip(
                          label: Text(c),
                          selected: true,
                          onSelected: (_) => setState(() => _avoid.remove(c)),
                          selectedColor: const Color(0xFFFFE8E4),
                          checkmarkColor: GlowColors.coral,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: GlowColors.coral),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              _customChipField(
                target: _avoid,
                hint: t('home.custom.avoid.hint'),
                accent: GlowColors.coral,
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: t('home.selfie'), step: '6'),
              const SizedBox(height: 10),
              _SelfieCard(
                photo: _photo,
                caption: t('home.selfie.optional'),
                onTap: _loading
                    ? null
                    : () async {
                        await _showPhotoSheet();
                        if (_photo == null && mounted) {
                          setState(() => _photoConsent = false);
                        }
                      },
              ),
              if (_photo != null) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _photoConsent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _photoConsent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    t('home.consent'),
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: GlowColors.coral)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(t('home.cta')),
              ),
              const SizedBox(height: 12),
              Text(
                t('disclaimer'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpBanner extends StatelessWidget {
  const _FollowUpBanner({
    required this.destination,
    required this.savedAt,
    required this.onOpen,
    required this.onRepeat,
    required this.lastLabel,
    required this.openLabel,
  });

  final String destination;
  final DateTime savedAt;
  final VoidCallback onOpen;
  final VoidCallback onRepeat;
  final String lastLabel;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlowColors.sea.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$lastLabel → $destination',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onOpen, child: Text(openLabel)),
              FilledButton.tonal(
                onPressed: onRepeat,
                child: Text(AppLocale.instance.t('profile.followup')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MvpHint extends StatelessWidget {
  const _MvpHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlowColors.line),
      ),
      child: Text(
        text,
        style: const TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.mode, required this.subtitle});

  final String mode;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [GlowColors.seaDeep, GlowColors.sea],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GlowAi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
    required this.preLabel,
    required this.sosLabel,
    required this.returnLabel,
  });

  final String mode;
  final ValueChanged<String> onChanged;
  final String preLabel;
  final String sosLabel;
  final String returnLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ModeTab(
                label: preLabel,
                selected: mode == 'pre_trip',
                onTap: () => onChanged('pre_trip'),
              ),
              _ModeTab(
                label: sosLabel,
                selected: mode == 'sos',
                onTap: () => onChanged('sos'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _ModeTab(
                label: returnLabel,
                selected: mode == 'return_home',
                onTap: () => onChanged('return_home'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? GlowColors.foam : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? GlowColors.seaDeep : GlowColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.caption,
    required this.value,
    required this.onTap,
  });

  final String caption;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GlowColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: const TextStyle(color: GlowColors.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.step});

  final String text;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: GlowColors.sea,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.caption,
    required this.city,
    required this.onTap,
  });

  final String caption;
  final PlaceOption city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GlowColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: const TextStyle(color: GlowColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                city.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                city.country,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GlowColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfieCard extends StatelessWidget {
  const _SelfieCard({required this.photo, required this.onTap, required this.caption});

  final XFile? photo;
  final VoidCallback? onTap;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        height: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: GlowColors.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: photo == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.face_retouching_natural, size: 42, color: GlowColors.sea),
                      const SizedBox(height: 10),
                      Text(
                        caption,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder(
                      future: photo!.readAsBytes(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      },
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: Colors.black45,
                        child: const Text(
                          'Нажмите, чтобы заменить',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
