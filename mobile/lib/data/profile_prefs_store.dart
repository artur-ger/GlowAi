import 'package:shared_preferences/shared_preferences.dart';

class ProfilePrefsStore {
  static const _onboardedKey = 'glowai_onboarded_v1';
  static const _skinKey = 'glowai_skin_type_v1';
  static const _concernsKey = 'glowai_concerns_v1';
  static const _ownedKey = 'glowai_owned_v1';
  static const _avoidKey = 'glowai_avoid_v1';

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

  Future<({String skinType, Set<String> concerns, Set<String> owned, Set<String> avoid})?> loadFormMemory() async {
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
}
