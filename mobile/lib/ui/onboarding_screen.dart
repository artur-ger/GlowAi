import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/profile_prefs_store.dart';
import '../l10n/app_locale.dart';
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
  int _page = 0;

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
    await _prefs.setOnboarded(true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final t = _locale.t;
    final pages = [
      (t('onboard.t1'), t('onboard.b1')),
      (t('onboard.t2'), t('onboard.b2')),
      (t('onboard.t3'), t('onboard.b3')),
    ];

    final current = pages[_page];
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
              const Spacer(),
              Row(
                children: List.generate(
                  pages.length,
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
                onPressed: () {
                  if (_page >= pages.length - 1) {
                    _finish();
                  } else {
                    setState(() => _page++);
                  }
                },
                child: Text(_page >= pages.length - 1 ? t('onboard.start') : t('onboard.next')),
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
}
