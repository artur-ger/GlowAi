import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_sync.dart';
import '../data/auth_api.dart';
import '../data/auth_store.dart';
import '../data/checks_api.dart';
import '../data/follow_up_bridge.dart';
import '../data/profile_prefs_store.dart';
import '../data/trips_api.dart';
import 'auth_screen.dart';
import 'check_chat_screen.dart';
import 'checkin_screen.dart';
import 'result_screen.dart';
import '../l10n/app_locale.dart';
import 'widgets/active_trip_card.dart';
import 'widgets/language_toggle.dart';
import 'widgets/legal_links.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onRequestFollowUp});

  final VoidCallback? onRequestFollowUp;

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _store = AuthStore();
  final _authApi = AuthApi();
  final _checksApi = ChecksApi();
  final _tripsApi = TripsApi();
  final _sync = AppSync.instance;

  bool _loading = true;
  bool _refreshing = false;
  bool _loggedIn = false;
  String _title = 'Профиль';
  List<CheckListItem> _items = [];
  List<CheckListItem> _due = [];
  TripItem? _activeTrip;
  DailyTip? _dailyTip;
  bool _tipLoading = false;
  String? _error;
  int _seenChecksEpoch = -1;
  int _seenSessionEpoch = -1;
  int _reloadGen = 0;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSync);
    _reload();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    // Invalidate only when something actually changed elsewhere (save/login).
    ensureFresh();
  }

  bool get _isDirty =>
      _sync.checksEpoch != _seenChecksEpoch || _sync.sessionEpoch != _seenSessionEpoch;

  /// Called when user opens Profile tab or AppSync notifies. Refetches only if dirty.
  void ensureFresh() {
    if (!_isDirty) return;
    _reload(silent: _loggedIn || _items.isNotEmpty);
  }

  Future<void> _reload({bool silent = false}) async {
    final gen = ++_reloadGen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _refreshing = true);
    }
    final loggedIn = await _store.isLoggedIn;
    if (!mounted || gen != _reloadGen) return;
    if (!loggedIn) {
      setState(() {
        _loggedIn = false;
        _items = [];
        _due = [];
        _activeTrip = null;
        _dailyTip = null;
        _loading = false;
        _refreshing = false;
        _title = 'Профиль';
        _seenChecksEpoch = _sync.checksEpoch;
        _seenSessionEpoch = _sync.sessionEpoch;
      });
      if (_isDirty) ensureFresh();
      return;
    }
    try {
      final me = await _authApi.me();
      final items = await _checksApi.listChecks();
      List<CheckListItem> due = [];
      TripItem? trip;
      DailyTip? tip;
      try {
        due = await _checksApi.listDueReminders();
      } catch (_) {
        due = [];
      }
      try {
        trip = await _tripsApi.activeTrip();
        if (trip != null && (trip.status == 'on_site' || trip.status == 'return_home')) {
          tip = await _tripsApi.dailyTip(trip.id);
        }
      } catch (_) {}
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _loggedIn = true;
        _title = me.displayName.isNotEmpty ? me.displayName : me.email;
        _items = items;
        _due = due;
        _activeTrip = trip;
        _dailyTip = tip;
        _loading = false;
        _refreshing = false;
        _error = null;
        _seenChecksEpoch = _sync.checksEpoch;
        _seenSessionEpoch = _sync.sessionEpoch;
      });
      if (_isDirty) ensureFresh();
    } catch (_) {
      await _store.clear();
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _loggedIn = false;
        _items = [];
        _due = [];
        _activeTrip = null;
        _dailyTip = null;
        _loading = false;
        _refreshing = false;
        _error = 'Сессия истекла — войдите снова.';
        _seenChecksEpoch = _sync.checksEpoch;
        _seenSessionEpoch = _sync.sessionEpoch;
      });
    }
  }

  Future<void> _openAuth() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (ok == true) await _reload();
  }

  Future<void> _logout() async {
    await ProfilePrefsStore().clearClimateLocal();
    await _authApi.logout();
    // AppSync.sessionChanged → root gate returns to AuthScreen.
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Будут удалены профиль, все проверки и чаты. Действие необратимо.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _authApi.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аккаунт удалён')),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить аккаунт')),
      );
    }
  }

  void _armFollowUp(CheckListItem item) {
    FollowUpBridge.arm(
      parentId: item.id,
      home: item.homeCity,
      dest: item.destCity,
    );
    widget.onRequestFollowUp?.call();
  }

  Future<void> _openCheck(CheckListItem item) async {
    try {
      final result = await _checksApi.getCheckPayload(item.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            cloudCheckId: item.id,
            parentCheckId: item.parentCheckId,
            onFollowUp: () {
              Navigator.of(context).pop();
              _armFollowUp(item);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть проверку')),
      );
    }
  }

  Future<void> _openChat(CheckListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckChatScreen(
          checkId: item.id,
          title: item.destCity.isEmpty ? 'Чат' : item.destCity,
        ),
      ),
    );
  }

  Future<void> _openCheckIn(CheckListItem item) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckInScreen(
          checkId: item.id,
          title: 'Check-in · ${item.destCity}',
        ),
      ),
    );
    if (ok == true) await _reload();
  }

  Future<void> _deleteCheck(CheckListItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить проверку?'),
        content: Text('${item.homeCity} → ${item.destCity}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _checksApi.deleteCheck(item.id);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить')),
      );
    }
  }

  Future<void> _setTripStatus(String status) async {
    final trip = _activeTrip;
    if (trip == null) return;
    try {
      final updated = await _tripsApi.setStatus(trip.id, status);
      if (!mounted) return;
      setState(() => _activeTrip = updated.isActive ? updated : null);
      if (status == 'on_site' || status == 'return_home') {
        setState(() => _tipLoading = true);
        final tip = await _tripsApi.dailyTip(trip.id);
        if (!mounted) return;
        setState(() {
          _dailyTip = tip;
          _tipLoading = false;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: Text(_loggedIn ? _title : AppLocale.instance.t('profile.title')),
        backgroundColor: GlowColors.mist,
        actions: [
          const LanguageToggle(),
          if (_loggedIn) ...[
            IconButton(
              tooltip: AppLocale.instance.t('profile.delete.account'),
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: AppLocale.instance.t('profile.logout'),
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_loggedIn
              ? _GuestBody(error: _error, onLogin: _openAuth)
              : RefreshIndicator(
                  onRefresh: () => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_refreshing)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_activeTrip != null) ...[
                        ActiveTripCard(
                          trip: _activeTrip!,
                          tip: _dailyTip,
                          loadingTip: _tipLoading,
                          onStatus: _setTripStatus,
                          onRefreshTip: () async {
                            final t = _activeTrip;
                            if (t == null) return;
                            setState(() => _tipLoading = true);
                            try {
                              final tip = await _tripsApi.dailyTip(t.id);
                              if (!mounted) return;
                              setState(() {
                                _dailyTip = tip;
                                _tipLoading = false;
                              });
                            } catch (_) {
                              if (mounted) setState(() => _tipLoading = false);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      const LegalLinks(compact: true),
                      const SizedBox(height: 12),
                      if (_due.isNotEmpty) ...[
                        const Text(
                          'Пора оценить кожу',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        for (final item in _due) ...[
                          _CheckCard(
                            item: item,
                            highlight: true,
                            onPlan: () => _openCheck(item),
                            onChat: () => _openChat(item),
                            onFollowUp: () => _armFollowUp(item),
                            onCheckIn: () => _openCheckIn(item),
                            onDelete: () => _deleteCheck(item),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Text(
                            'Пока нет сохранённых проверок.\nСделайте анализ и нажмите «Сохранить в профиль».',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GlowColors.muted, height: 1.4),
                          ),
                        )
                      else ...[
                        const Text(
                          'История',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        for (final item in _items) ...[
                          _CheckCard(
                            item: item,
                            onPlan: () => _openCheck(item),
                            onChat: () => _openChat(item),
                            onFollowUp: () => _armFollowUp(item),
                            onCheckIn: () => _openCheckIn(item),
                            onDelete: () => _deleteCheck(item),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.item,
    required this.onPlan,
    required this.onChat,
    required this.onFollowUp,
    required this.onCheckIn,
    required this.onDelete,
    this.highlight = false,
  });

  final CheckListItem item;
  final VoidCallback onPlan;
  final VoidCallback onChat;
  final VoidCallback onFollowUp;
  final VoidCallback onCheckIn;
  final VoidCallback onDelete;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? GlowColors.foam : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.homeCity} → ${item.destCity}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.mode} · ${item.engine}'
            '${item.parentCheckId != null ? ' · follow-up #${item.parentCheckId}' : ''}'
            '${item.createdAt != null ? ' · ${item.createdAt}' : ''}',
            style: const TextStyle(color: GlowColors.muted, fontSize: 12),
          ),
          if (item.remindAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Напоминание: ${item.remindAt}',
              style: const TextStyle(color: GlowColors.seaDeep, fontSize: 12),
            ),
          ],
          if (item.forecastSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.forecastSummary, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: onPlan,
                child: const Text('План'),
              ),
              FilledButton(
                onPressed: onChat,
                child: const Text('Чат'),
              ),
              OutlinedButton(
                onPressed: onFollowUp,
                child: const Text('Повторная оценка'),
              ),
              FilledButton.tonal(
                onPressed: onCheckIn,
                child: const Text('Check-in'),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: GlowColors.coral),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestBody extends StatelessWidget {
  const _GuestBody({required this.onLogin, this.error});

  final VoidCallback onLogin;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            AppLocale.instance.t('profile.guest'),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: GlowColors.coral)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: onLogin, child: Text(AppLocale.instance.t('profile.login'))),
        ],
      ),
    );
  }
}
