import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/trips_api.dart';
import '../../l10n/app_locale.dart';

class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({
    super.key,
    required this.trip,
    this.tip,
    this.onStatus,
    this.onRefreshTip,
    this.loadingTip = false,
  });

  final TripItem trip;
  final DailyTip? tip;
  final ValueChanged<String>? onStatus;
  final VoidCallback? onRefreshTip;
  final bool loadingTip;

  @override
  Widget build(BuildContext context) {
    final t = AppLocale.instance.t;
    final statuses = [
      ('pre_trip', t('trip.pre')),
      ('on_site', t('trip.onsite')),
      ('return_home', t('trip.return')),
      ('done', t('trip.done')),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlowColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('trip.active')} · ${trip.statusLabel}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('${trip.homeCity} → ${trip.destCity}'),
          if (trip.suggestedNext.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trip.suggestedNext,
              style: const TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in statuses)
                ChoiceChip(
                  label: Text(s.$2),
                  selected: trip.status == s.$1,
                  onSelected: onStatus == null ? null : (_) => onStatus!(s.$1),
                  selectedColor: GlowColors.foam,
                ),
            ],
          ),
          if (trip.status == 'on_site' || trip.status == 'return_home') ...[
            const SizedBox(height: 10),
            if (loadingTip)
              const LinearProgressIndicator(minHeight: 2)
            else if (tip != null) ...[
              Text(
                '${tip!.city}'
                '${tip!.tempC != null ? ' · ${tip!.tempC!.toStringAsFixed(0)}°' : ''}'
                '${tip!.uv != null ? ' · UV ${tip!.uv!.toStringAsFixed(1)}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(tip!.tip, style: const TextStyle(height: 1.35, fontSize: 13)),
            ],
            TextButton(
              onPressed: onRefreshTip,
              child: Text(tip == null ? t('trip.tip') : t('trip.tip.refresh')),
            ),
          ],
        ],
      ),
    );
  }
}
