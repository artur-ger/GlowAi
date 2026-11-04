import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Экран ожидания анализа (паттерн readable report flow, без лишнего onboarding).
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.destination});

  final String destination;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  int _step = 0;
  final _labels = const [
    'Сверяем климат маршрута…',
    'Учитываем тип кожи и симптомы…',
    'Собираем план и travel-kit…',
  ];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _step = (_step + 1) % _labels.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlowColors.mist,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: GlowColors.foam,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(color: GlowColors.sea, strokeWidth: 3),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Готовим travel-прогноз кожи',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Направление: ${widget.destination}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GlowColors.muted),
                ),
                const SizedBox(height: 18),
                Text(
                  _labels[_step],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GlowColors.seaDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
