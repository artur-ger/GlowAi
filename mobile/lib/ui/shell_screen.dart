import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_locale.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  final _todayKey = GlobalKey<TodayScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _locale = AppLocale.instance;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocale);
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  void _goPlanForFollowUp() {
    setState(() => _index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.consumeFollowUpBridge();
    });
  }

  void _onTab(int i) {
    setState(() => _index = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (i == 1) {
        _homeKey.currentState?.consumeFollowUpBridge();
      } else if (i == 2) {
        _profileKey.currentState?.ensureFresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _locale.t;
    return Scaffold(
      backgroundColor: GlowColors.mist,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                TodayScreen(key: _todayKey),
                HomeScreen(key: _homeKey),
                ProfileScreen(
                  key: _profileKey,
                  onRequestFollowUp: _goPlanForFollowUp,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    _NavItem(
                      selected: _index == 0,
                      icon: Icons.wb_sunny_outlined,
                      selectedIcon: Icons.wb_sunny,
                      label: t('nav.today'),
                      onTap: () => _onTab(0),
                    ),
                    _NavItem(
                      selected: _index == 1,
                      icon: Icons.flight_takeoff_outlined,
                      selectedIcon: Icons.flight_takeoff,
                      label: t('nav.trip'),
                      hint: t('nav.trip.hint'),
                      onTap: () => _onTab(1),
                    ),
                    _NavItem(
                      selected: _index == 2,
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: t('nav.profile'),
                      onTap: () => _onTab(2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? GlowColors.sea : GlowColors.muted;
    return Expanded(
      child: Tooltip(
        message: hint ?? label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
