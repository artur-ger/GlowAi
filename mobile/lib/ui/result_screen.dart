import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/auth_store.dart';
import '../data/checks_api.dart';
import '../data/models.dart';
import 'auth_screen.dart';
import 'check_chat_screen.dart';
import 'checkin_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.onFollowUp,
    this.cloudCheckId,
    this.parentCheckId,
  });

  final AnalyzeResult result;
  final VoidCallback? onFollowUp;
  final int? cloudCheckId;
  /// When this result is a SOS re-check linked to a previous cloud check.
  final int? parentCheckId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _store = AuthStore();
  final _checks = ChecksApi();
  int? _checkId;
  bool _saving = false;
  bool _scheduleRemind = true;
  String? _saveMsg;

  @override
  void initState() {
    super.initState();
    _checkId = widget.cloudCheckId;
  }

  Future<void> _saveToProfile() async {
    setState(() {
      _saving = true;
      _saveMsg = null;
    });
    final loggedIn = await _store.isLoggedIn;
    if (!loggedIn) {
      if (!mounted) return;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (ok != true) {
        setState(() => _saving = false);
        return;
      }
    }
    try {
      final c = widget.result.climate;
      final parentId = widget.parentCheckId;
      final saved = await _checks.saveCheck(
        result: widget.result,
        homeCity: c.homeCity,
        destCity: c.destinationCity,
        parentCheckId: parentId,
        remindInHours: _scheduleRemind && widget.result.mode == 'pre_trip' ? 48 : null,
      );
      if (!mounted) return;
      setState(() {
        _checkId = saved.id;
        _saving = false;
        _saveMsg = _scheduleRemind && saved.remindAt != null
            ? 'Сохранено (#${saved.id}). Напоминание follow-up: ${saved.remindAt}'
            : 'Сохранено в профиль (#${saved.id})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMsg = 'Не удалось сохранить. Войдите и попробуйте снова.';
      });
    }
  }

  Future<void> _setRemindNow() async {
    final id = _checkId;
    if (id == null) {
      await _saveToProfile();
      return;
    }
    try {
      final updated = await _checks.setRemind(checkId: id, hours: 48);
      if (!mounted) return;
      setState(() => _saveMsg = 'Напоминание: ${updated.remindAt}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveMsg = 'Не удалось поставить напоминание.');
    }
  }

  Future<void> _openChat() async {
    var id = _checkId;
    if (id == null) {
      await _saveToProfile();
      id = _checkId;
    }
    if (id == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckChatScreen(
          checkId: id!,
          title: widget.result.climate.destinationCity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final c = result.climate;
    final take = result.packingKit.where((e) => e.action == 'take').toList();
    final skip = result.packingKit.where((e) => e.action == 'skip').toList();

    return Scaffold(
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: const Text('Прогноз кожи к поездке'),
        backgroundColor: GlowColors.mist,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _HeroSummary(result: result),
          const SizedBox(height: 10),
          _EngineBadge(result: result),
          const SizedBox(height: 12),
          if (widget.result.mode == 'pre_trip' && _checkId == null)
            CheckboxListTile(
              value: _scheduleRemind,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _scheduleRemind = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Напомнить о повторной оценке через 48 ч',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _saving ? null : _saveToProfile,
                child: Text(_checkId == null ? 'Сохранить в профиль' : 'Сохранено #$_checkId'),
              ),
              FilledButton(
                onPressed: _saving ? null : _openChat,
                child: const Text('Обсудить состояние'),
              ),
              if (_checkId != null)
                OutlinedButton(
                  onPressed: _saving ? null : _setRemindNow,
                  child: const Text('Напомнить через 48 ч'),
                ),
              if (_checkId != null)
                FilledButton.tonal(
                  onPressed: _saving
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckInScreen(
                                checkId: _checkId!,
                                title: 'Check-in · ${widget.result.climate.destinationCity}',
                              ),
                            ),
                          );
                        },
                  child: const Text('Check-in 48–72ч'),
                ),
            ],
          ),
          if (_saveMsg != null) ...[
            const SizedBox(height: 8),
            Text(_saveMsg!, style: const TextStyle(color: GlowColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          _ClimateCompare(climate: c),
          if (result.whyReasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Card(
              title: 'Почему такой план',
              child: Column(
                children: [
                  for (final reason in result.whyReasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: GlowColors.sun),
                          const SizedBox(width: 8),
                          Expanded(child: Text(reason, style: const TextStyle(height: 1.35))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Card(
            title: 'Состояние кожи',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.skin.summary, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.skin.concerns
                      .map(
                        (e) => Chip(
                          label: Text(e),
                          backgroundColor: GlowColors.foam,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            title: 'План ухода',
            child: Column(
              children: [
                for (final s in result.carePlan) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: GlowColors.foam,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${s.step}',
                          style: const TextStyle(
                            color: GlowColors.seaDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(s.detail, style: const TextStyle(color: GlowColors.muted, height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (s != result.carePlan.last) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            title: 'Travel-kit: взять',
            child: take.isEmpty
                ? Text(result.packingList.join('\n'))
                : Column(
                    children: [
                      for (final item in take)
                        _KitRow(
                          icon: Icons.check_circle_outline,
                          color: GlowColors.sea,
                          title: item.item,
                          subtitle: item.reason,
                        ),
                    ],
                  ),
          ),
          if (skip.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Card(
              title: 'Можно не брать',
              child: Column(
                children: [
                  for (final item in skip)
                    _KitRow(
                      icon: Icons.remove_circle_outline,
                      color: GlowColors.coral,
                      title: item.item,
                      subtitle: item.reason,
                    ),
                ],
              ),
            ),
          ],
          if (result.productHints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Card(
              title: 'Категории средств',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.productHints
                    .map(
                      (e) => Chip(
                        label: Text(e),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: GlowColors.line),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Card(
            title: 'Через 48–72 часа',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.followUpHint, style: const TextStyle(height: 1.4)),
                if (widget.onFollowUp != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: widget.onFollowUp,
                    child: const Text('Повторная оценка (режим SOS)'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.disclaimer,
            style: const TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _EngineBadge extends StatelessWidget {
  const _EngineBadge({required this.result});

  final AnalyzeResult result;

  @override
  Widget build(BuildContext context) {
    final llm = result.isLlmEngine;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: llm ? GlowColors.foam : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlowColors.line),
      ),
      child: Row(
        children: [
          Icon(
            llm ? Icons.auto_awesome : Icons.rule_folder_outlined,
            size: 18,
            color: GlowColors.seaDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'План: ${result.engineLabel} · уверенность: ${result.skin.confidence}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.result});

  final AnalyzeResult result;

  @override
  Widget build(BuildContext context) {
    final c = result.climate;
    final dates = (result.tripStart != null && result.tripEnd != null)
        ? '${result.tripStart} → ${result.tripEnd}'
        : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [GlowColors.seaDeep, GlowColors.sea]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (result.mode) {
              'sos' => 'SOS-план готов',
              'return_home' => 'План возврата домой',
              _ => 'Прогноз кожи к поездке',
            },
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${c.homeCity}  →  ${c.destinationCity}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (dates != null) ...[
            const SizedBox(height: 4),
            Text(
              result.tripDays != null ? '$dates · ${result.tripDays} дн.' : dates,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
          ],
          if (result.forecastSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              result.forecastSummary,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClimateCompare extends StatelessWidget {
  const _ClimateCompare({required this.climate});

  final ClimateSummary climate;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Климат: дом vs поездка',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: 'Дом',
                  temp: climate.homeTempC,
                  humidity: climate.homeHumidity,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'На месте',
                  temp: climate.destinationTempC,
                  humidity: climate.destinationHumidity,
                  accent: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'UV на месте: ${climate.destinationUv?.toStringAsFixed(1) ?? "—"}'
            '${climate.deltaTempC != null ? " · ΔT ${climate.deltaTempC!.toStringAsFixed(0)}°" : ""}'
            '${climate.deltaHumidity != null ? " · Δвлажн. ${climate.deltaHumidity!.toStringAsFixed(0)}%" : ""}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${climate.windowLabel}'
            '${climate.windowNote.isNotEmpty ? ' — ${climate.windowNote}' : ''}',
            style: const TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          ...climate.risks.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 18, color: GlowColors.sun),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(height: 1.3))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.temp,
    required this.humidity,
    this.accent = false,
  });

  final String label;
  final double? temp;
  final double? humidity;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? GlowColors.foam : GlowColors.mist,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: GlowColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${temp?.toStringAsFixed(0) ?? "—"}°',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            'влажн. ${humidity?.toStringAsFixed(0) ?? "—"}%',
            style: const TextStyle(color: GlowColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KitRow extends StatelessWidget {
  const _KitRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: GlowColors.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
