import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/profile_prefs_store.dart';
import 'l10n/app_locale.dart';
import 'ui/onboarding_screen.dart';
import 'ui/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlowAiApp());
}

class GlowAiApp extends StatefulWidget {
  const GlowAiApp({super.key});

  @override
  State<GlowAiApp> createState() => _GlowAiAppState();
}

class _GlowAiAppState extends State<GlowAiApp> {
  final _prefs = ProfilePrefsStore();
  final _locale = AppLocale.instance;
  bool _loading = true;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _locale.load();
    final ok = await _prefs.isOnboarded;
    if (!mounted) return;
    setState(() {
      _onboarded = ok;
      _loading = false;
    });
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
          home: _loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _onboarded
                  ? const ShellScreen()
                  : OnboardingScreen(
                      onDone: () => setState(() => _onboarded = true),
                    ),
        );
      },
    );
  }
}
