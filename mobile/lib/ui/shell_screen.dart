import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_locale.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
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
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.consumeFollowUpBridge();
    });
  }

  void _onTab(int i) {
    setState(() => _index = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (i == 0) {
        _homeKey.currentState?.consumeFollowUpBridge();
      } else if (i == 1) {
        _profileKey.currentState?.ensureFresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _locale.t;
    // Column + nav (not Scaffold.bottomNavigationBar): on Flutter web the
    // bottom bar was a solid grey strip with no destinations painted.
    return Scaffold(
      backgroundColor: GlowColors.mist,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
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
                      icon: Icons.flight_takeoff_outlined,
                      selectedIcon: Icons.flight_takeoff,
                      label: t('nav.plan'),
                      onTap: () => _onTab(0),
                    ),
                    _NavItem(
                      selected: _index == 1,
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: t('nav.profile'),
                      onTap: () => _onTab(1),
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
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? GlowColors.sea : GlowColors.muted;
    return Expanded(
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
    );
  }
}
