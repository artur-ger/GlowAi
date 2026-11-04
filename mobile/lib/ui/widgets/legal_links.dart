import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/open_url.dart';
import '../../core/theme.dart';

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = AppConfig.apiBaseUrl;
    final style = TextStyle(
      color: GlowColors.seaDeep,
      fontSize: compact ? 11 : 13,
      decoration: TextDecoration.underline,
      decorationColor: GlowColors.seaDeep.withValues(alpha: 0.4),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        GestureDetector(
          onTap: () => openUrl('$base/legal/terms'),
          child: Text('Условия', style: style),
        ),
        GestureDetector(
          onTap: () => openUrl('$base/legal/privacy'),
          child: Text('Политика ПДн', style: style),
        ),
      ],
    );
  }
}
