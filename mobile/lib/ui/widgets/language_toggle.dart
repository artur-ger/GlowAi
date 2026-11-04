import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_locale.dart';

/// Compact RU/EN control — SegmentedButton on Flutter web often blows layout.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return ListenableBuilder(
      listenable: loc,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangChip(
              label: loc.t('lang.ru'),
              selected: loc.code == 'ru',
              onTap: () => loc.setCode('ru'),
            ),
            const SizedBox(width: 6),
            _LangChip(
              label: loc.t('lang.en'),
              selected: loc.code == 'en',
              onTap: () => loc.setCode('en'),
            ),
          ],
        );
      },
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GlowColors.sea : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? GlowColors.sea : GlowColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : GlowColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
