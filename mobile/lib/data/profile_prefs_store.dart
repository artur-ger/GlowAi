import 'package:shared_preferences/shared_preferences.dart';

import 'climate_models.dart';

class ClimateProfilePrefs {
  const ClimateProfilePrefs({
    this.cityName = 'Москва',
    this.cityCountry = 'Россия',
    this.cityCountryCode = 'RU',
    this.lat,
    this.lon,
    this.coldBias = 0,
    this.heatBias = 0,
    this.activity = 'moderate',
    this.ageBand = 'unknown',
    this.sex = 'unknown',
    this.dressBias = 'typical',
    this.acclimation = 'unknown',
    this.vignetteSensation = 'unknown',
    this.feedbackOffset = 0,
    this.feedbackCount = 0,
    this.clientKey = 'anon',
    this.skinNote = '',
    this.habits = const {},
    this.allergies = const {},
    this.leaveHour = 8,
    this.returnHour = 19,
    this.customClothing = const {},
    this.customCare = const {},
  });

  final String cityName;
  final String cityCountry;
  final String cityCountryCode;
  final double? lat;
  final double? lon;
  final double coldBias;
  final double heatBias;
  final String activity;
  final String ageBand;
  final String sex;
  final String dressBias;
  final String acclimation;
  final String vignetteSensation;
  final double feedbackOffset;
  final int feedbackCount;
  final String clientKey;
  final String skinNote;
  final Set<String> habits;
  final Set<String> allergies;
  final int leaveHour;
  final int returnHour;
  final Set<String> customClothing;
  final Set<String> customCare;

  ClimateProfilePayload toPayload() => ClimateProfilePayload(
        coldBias: coldBias,
        heatBias: heatBias,
        activity: activity,
        ageBand: ageBand,
        sex: sex,
        dressBias: dressBias,
        acclimation: acclimation,
        vignetteSensation: vignetteSensation,
        feedbackOffset: feedbackOffset,
        feedbackCount: feedbackCount,
        habits: habits.toList(),
        allergies: {
          ...allergies,
          if (skinNote.isNotEmpty) skinNote,
        }.toList(),
        leaveHour: leaveHour,
        returnHour: returnHour,
      );

  ClimateProfilePrefs copyWith({
    String? cityName,
    String? cityCountry,
    String? cityCountryCode,
    double? lat,
    double? lon,
    bool clearCoords = false,
    double? coldBias,
    double? heatBias,
    String? activity,
    String? ageBand,
    String? sex,
    String? dressBias,
    String? acclimation,
    String? vignetteSensation,
    double? feedbackOffset,
    int? feedbackCount,
    String? clientKey,
    String? skinNote,
    Set<String>? habits,
    Set<String>? allergies,
    int? leaveHour,
    int? returnHour,
    Set<String>? customClothing,
    Set<String>? customCare,
  }) {
    return ClimateProfilePrefs(
      cityName: cityName ?? this.cityName,
      cityCountry: cityCountry ?? this.cityCountry,
      cityCountryCode: cityCountryCode ?? this.cityCountryCode,
      lat: clearCoords ? null : (lat ?? this.lat),
      lon: clearCoords ? null : (lon ?? this.lon),
      coldBias: coldBias ?? this.coldBias,
      heatBias: heatBias ?? this.heatBias,
      activity: activity ?? this.activity,
      ageBand: ageBand ?? this.ageBand,
      sex: sex ?? this.sex,
      dressBias: dressBias ?? this.dressBias,
      acclimation: acclimation ?? this.acclimation,
      vignetteSensation: vignetteSensation ?? this.vignetteSensation,
      feedbackOffset: feedbackOffset ?? this.feedbackOffset,
      feedbackCount: feedbackCount ?? this.feedbackCount,
      clientKey: clientKey ?? this.clientKey,
      skinNote: skinNote ?? this.skinNote,
      habits: habits ?? this.habits,
      allergies: allergies ?? this.allergies,
      leaveHour: leaveHour ?? this.leaveHour,
      returnHour: returnHour ?? this.returnHour,
      customClothing: customClothing ?? this.customClothing,
      customCare: customCare ?? this.customCare,
    );
  }
}

class ProfilePrefsStore {
  static const _onboardedKey = 'glowai_onboarded_v1';
  static const _skinKey = 'glowai_skin_type_v1';
  static const _concernsKey = 'glowai_concerns_v1';
  static const _ownedKey = 'glowai_owned_v1';
  static const _avoidKey = 'glowai_avoid_v1';

  static const _cityNameKey = 'glowai_climate_city_v1';
  static const _cityCountryKey = 'glowai_climate_country_v1';
  static const _cityCodeKey = 'glowai_climate_cc_v1';
  static const _latKey = 'glowai_climate_lat_v1';
  static const _lonKey = 'glowai_climate_lon_v1';
  static const _coldKey = 'glowai_climate_cold_v1';
  static const _heatKey = 'glowai_climate_heat_v1';
  static const _activityKey = 'glowai_climate_activity_v1';
  static const _ageKey = 'glowai_climate_age_v1';
  static const _sexKey = 'glowai_climate_sex_v1';
  static const _dressKey = 'glowai_climate_dress_v1';
  static const _acclimationKey = 'glowai_climate_acclimation_v1';
  static const _vignetteKey = 'glowai_climate_vignette_v1';
  static const _feedbackKey = 'glowai_climate_feedback_v1';
  static const _feedbackCountKey = 'glowai_climate_feedback_count_v1';
  static const _clientKey = 'glowai_climate_client_key_v1';
  static const _skinNoteKey = 'glowai_climate_skin_note_v1';
  static const _habitsKey = 'glowai_climate_habits_v1';
  static const _allergiesKey = 'glowai_climate_allergies_v1';
  static const _leaveKey = 'glowai_climate_leave_h_v1';
  static const _returnKey = 'glowai_climate_return_h_v1';
  static const _customClothesKey = 'glowai_climate_custom_clothes_v1';
  static const _customCareKey = 'glowai_climate_custom_care_v1';

  Future<bool> get isOnboarded async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, value);
  }

  Future<void> saveFormMemory({
    required String skinType,
    required Set<String> concerns,
    required Set<String> owned,
    required Set<String> avoid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skinKey, skinType);
    await prefs.setStringList(_concernsKey, concerns.toList());
    await prefs.setStringList(_ownedKey, owned.toList());
    await prefs.setStringList(_avoidKey, avoid.toList());
  }

  Future<({String skinType, Set<String> concerns, Set<String> owned, Set<String> avoid})?>
      loadFormMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = prefs.getString(_skinKey);
    if (skin == null || skin.isEmpty) return null;
    return (
      skinType: skin,
      concerns: (prefs.getStringList(_concernsKey) ?? []).toSet(),
      owned: (prefs.getStringList(_ownedKey) ?? []).toSet(),
      avoid: (prefs.getStringList(_avoidKey) ?? []).toSet(),
    );
  }

  Future<ClimateProfilePrefs> loadClimateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    var clientKey = prefs.getString(_clientKey);
    if (clientKey == null || clientKey.isEmpty || clientKey == 'anon') {
      clientKey = 'c${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_clientKey, clientKey);
    }
    return ClimateProfilePrefs(
      cityName: prefs.getString(_cityNameKey) ?? 'Москва',
      cityCountry: prefs.getString(_cityCountryKey) ?? 'Россия',
      cityCountryCode: prefs.getString(_cityCodeKey) ?? 'RU',
      lat: prefs.getDouble(_latKey),
      lon: prefs.getDouble(_lonKey),
      coldBias: prefs.getDouble(_coldKey) ?? 0,
      heatBias: prefs.getDouble(_heatKey) ?? 0,
      activity: prefs.getString(_activityKey) ?? 'moderate',
      ageBand: prefs.getString(_ageKey) ?? 'unknown',
      sex: prefs.getString(_sexKey) ?? 'unknown',
      dressBias: prefs.getString(_dressKey) ?? 'typical',
      acclimation: prefs.getString(_acclimationKey) ?? 'unknown',
      vignetteSensation: prefs.getString(_vignetteKey) ?? 'unknown',
      feedbackOffset: prefs.getDouble(_feedbackKey) ?? 0,
      feedbackCount: prefs.getInt(_feedbackCountKey) ?? 0,
      clientKey: clientKey,
      skinNote: prefs.getString(_skinNoteKey) ?? '',
      habits: (prefs.getStringList(_habitsKey) ?? []).toSet(),
      allergies: (prefs.getStringList(_allergiesKey) ?? []).toSet(),
      leaveHour: prefs.getInt(_leaveKey) ?? 8,
      returnHour: prefs.getInt(_returnKey) ?? 19,
      customClothing: (prefs.getStringList(_customClothesKey) ?? []).toSet(),
      customCare: (prefs.getStringList(_customCareKey) ?? []).toSet(),
    );
  }

  ClimateAccountProfile toAccountProfile(
    ClimateProfilePrefs profile, {
    required bool onboarded,
  }) {
    return ClimateAccountProfile(
      onboarded: onboarded,
      cityName: profile.cityName,
      cityCountry: profile.cityCountry,
      cityCountryCode: profile.cityCountryCode,
      lat: profile.lat,
      lon: profile.lon,
      coldBias: profile.coldBias,
      heatBias: profile.heatBias,
      activity: profile.activity,
      ageBand: profile.ageBand,
      sex: profile.sex,
      dressBias: profile.dressBias,
      acclimation: profile.acclimation,
      vignetteSensation: profile.vignetteSensation,
      feedbackOffset: profile.feedbackOffset,
      feedbackCount: profile.feedbackCount,
      habits: profile.habits.toList(),
      allergies: profile.allergies.toList(),
      skinNote: profile.skinNote,
      leaveHour: profile.leaveHour,
      returnHour: profile.returnHour,
      clientKey: profile.clientKey,
    );
  }

  ClimateProfilePrefs fromAccountProfile(ClimateAccountProfile account) {
    return ClimateProfilePrefs(
      cityName: account.cityName,
      cityCountry: account.cityCountry,
      cityCountryCode: account.cityCountryCode,
      lat: account.lat,
      lon: account.lon,
      coldBias: account.coldBias,
      heatBias: account.heatBias,
      activity: account.activity,
      ageBand: account.ageBand,
      sex: account.sex,
      dressBias: account.dressBias,
      acclimation: account.acclimation,
      vignetteSensation: account.vignetteSensation,
      feedbackOffset: account.feedbackOffset,
      feedbackCount: account.feedbackCount,
      clientKey: account.clientKey,
      skinNote: account.skinNote,
      habits: account.habits.toSet(),
      allergies: account.allergies.toSet(),
      leaveHour: account.leaveHour,
      returnHour: account.returnHour,
    );
  }

  Future<void> applyAccountProfile(ClimateAccountProfile account) async {
    await saveClimateProfile(fromAccountProfile(account));
    await setOnboarded(account.onboarded);
  }

  Future<void> clearClimateLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _onboardedKey,
      _cityNameKey,
      _cityCountryKey,
      _cityCodeKey,
      _latKey,
      _lonKey,
      _coldKey,
      _heatKey,
      _activityKey,
      _ageKey,
      _sexKey,
      _dressKey,
      _acclimationKey,
      _vignetteKey,
      _feedbackKey,
      _feedbackCountKey,
      _clientKey,
      _skinNoteKey,
      _habitsKey,
      _allergiesKey,
      _leaveKey,
      _returnKey,
      _customClothesKey,
      _customCareKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> saveClimateProfile(ClimateProfilePrefs profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityNameKey, profile.cityName);
    await prefs.setString(_cityCountryKey, profile.cityCountry);
    await prefs.setString(_cityCodeKey, profile.cityCountryCode);
    if (profile.lat != null) {
      await prefs.setDouble(_latKey, profile.lat!);
    } else {
      await prefs.remove(_latKey);
    }
    if (profile.lon != null) {
      await prefs.setDouble(_lonKey, profile.lon!);
    } else {
      await prefs.remove(_lonKey);
    }
    await prefs.setDouble(_coldKey, profile.coldBias);
    await prefs.setDouble(_heatKey, profile.heatBias);
    await prefs.setString(_activityKey, profile.activity);
    await prefs.setString(_ageKey, profile.ageBand);
    await prefs.setString(_sexKey, profile.sex);
    await prefs.setString(_dressKey, profile.dressBias);
    await prefs.setString(_acclimationKey, profile.acclimation);
    await prefs.setString(_vignetteKey, profile.vignetteSensation);
    await prefs.setDouble(_feedbackKey, profile.feedbackOffset);
    await prefs.setInt(_feedbackCountKey, profile.feedbackCount);
    await prefs.setString(_clientKey, profile.clientKey);
    await prefs.setString(_skinNoteKey, profile.skinNote);
    await prefs.setStringList(_habitsKey, profile.habits.toList());
    await prefs.setStringList(_allergiesKey, profile.allergies.toList());
    await prefs.setInt(_leaveKey, profile.leaveHour);
    await prefs.setInt(_returnKey, profile.returnHour);
    await prefs.setStringList(_customClothesKey, profile.customClothing.toList());
    await prefs.setStringList(_customCareKey, profile.customCare.toList());
  }
}
