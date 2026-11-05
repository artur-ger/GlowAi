import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/app_sync.dart';
import 'data/auth_store.dart';
import 'data/climate_api.dart';
import 'data/profile_prefs_store.dart';
import 'l10n/app_locale.dart';
import 'ui/auth_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlowAiApp());
}

enum _Gate { loading, auth, onboard, app }

class GlowAiApp extends StatefulWidget {
  const GlowAiApp({super.key});

  @override
  State<GlowAiApp> createState() => _GlowAiAppState();
}

class _GlowAiAppState extends State<GlowAiApp> {
  final _prefs = ProfilePrefsStore();
  final _auth = AuthStore();
  final _climateApi = ClimateApi();
  final _locale = AppLocale.instance;
  final _sync = AppSync.instance;

  _Gate _gate = _Gate.loading;
  int _sessionSeen = -1;

  @override
  void initState() {
    super.initState();
    _sessionSeen = _sync.sessionEpoch;
    _sync.addListener(_onSession);
    _boot();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    // Only react to real login/logout/delete — not the epoch we just applied.
    if (_sync.sessionEpoch == _sessionSeen) return;
    _sessionSeen = _sync.sessionEpoch;
    _boot();
  }

  Future<void> _enterFromAccount({required bool onboarded}) async {
    if (!mounted) return;
    setState(() => _gate = onboarded ? _Gate.app : _Gate.onboard);
  }

  Future<void> _boot() async {
    setState(() => _gate = _Gate.loading);
    await _locale.load();
    final loggedIn = await _auth.isLoggedIn;
    if (!loggedIn) {
      // Keep climate local only while a session exists; guest has no account data.
      if (!mounted) return;
      setState(() => _gate = _Gate.auth);
      return;
    }
    try {
      final account = await _climateApi.getAccountProfile();
      await _prefs.applyAccountProfile(account);
      await _enterFromAccount(onboarded: account.onboarded);
    } on StateError catch (_) {
      // Explicit unauthorized from API
      await _auth.clear();
      await _prefs.clearClimateLocal();
      if (!mounted) return;
      setState(() => _gate = _Gate.auth);
    } catch (_) {
      // Network / backend blip: keep JWT, use last local climate snapshot.
      final localOnboarded = await _prefs.isOnboarded;
      await _enterFromAccount(onboarded: localOnboarded);
    }
  }

  Future<void> _afterAuth() async {
    _sessionSeen = _sync.sessionEpoch;
    setState(() => _gate = _Gate.loading);
    try {
      final account = await _climateApi.getAccountProfile();
      await _prefs.applyAccountProfile(account);
      await _enterFromAccount(onboarded: account.onboarded);
    } on StateError catch (_) {
      await _auth.clear();
      if (!mounted) return;
      setState(() => _gate = _Gate.auth);
    } catch (_) {
      // Just logged in but profile fetch failed — still new until server says otherwise.
      final localOnboarded = await _prefs.isOnboarded;
      await _enterFromAccount(onboarded: localOnboarded);
    }
  }

  Future<void> _afterOnboard() async {
    final local = await _prefs.loadClimateProfile();
    final payload = _prefs.toAccountProfile(local, onboarded: true);
    try {
      final saved = await _climateApi.putAccountProfile(payload);
      await _prefs.applyAccountProfile(saved);
    } catch (_) {
      await _prefs.setOnboarded(true);
    }
    if (!mounted) return;
    setState(() => _gate = _Gate.app);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _locale,
      builder: (context, _) {
        return MaterialApp(
          title: 'GlowAi',
          debugShowCheckedModeBanner: false,
          theme: GlowTheme.light,
          locale: _locale.locale,
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: switch (_gate) {
            _Gate.loading => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            _Gate.auth => AuthScreen(onAuthed: _afterAuth),
            _Gate.onboard => OnboardingScreen(onDone: _afterOnboard),
            _Gate.app => const ShellScreen(),
          },
        );
      },
    );
  }
}
