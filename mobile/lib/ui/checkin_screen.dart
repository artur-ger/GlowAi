import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/checks_api.dart';
import '../data/models.dart';
import 'result_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, required this.checkId, this.title = 'Check-in'});

  final int checkId;
  final String title;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _api = ChecksApi();
  final _note = TextEditingController();

  int _dryness = 3;
  int _oiliness = 3;
  int _calmness = 3;
  int _redness = 3;
  bool _loading = false;
  String? _advice;
  String? _error;
  AnalyzeResult? _revised;
  int? _revisedId;
  bool _suggestSos = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _advice = null;
      _revised = null;
    });
    try {
      final res = await _api.submitCheckIn(
        checkId: widget.checkId,
        dryness: _dryness,
        oiliness: _oiliness,
        calmness: _calmness,
        redness: _redness,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      AnalyzeResult? revised;
      final payload = res['revised_payload'];
      if (payload is Map) {
        revised = AnalyzeResult.fromJson(Map<String, dynamic>.from(payload));
      }
      setState(() {
        _advice = res['advice'] as String? ?? 'Сохранено';
        _revised = revised;
        _revisedId = (res['revised_check_id'] as num?)?.toInt();
        _suggestSos = res['suggest_sos'] as bool? ?? false;
        _loading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data;
      setState(() {
        _loading = false;
        _error = detail is Map && detail['detail'] != null
            ? '${detail['detail']}'
            : 'Не удалось отправить check-in';
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Не удалось отправить check-in';
      });
    }
  }

  Widget _scale(String label, int value, ValueChanged<int> onChanged) {
    // Use plain buttons, not ChoiceChip: deselect callback on the old chip
    // was resetting the value (couldn't pick lower than current on web).
    final locked = _loading || _advice != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var v = 1; v <= 5; v++) ...[
              if (v > 1) const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: value == v ? GlowColors.sea : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: locked ? null : () => onChanged(v),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: value == v ? GlowColors.sea : GlowColors.line,
                        ),
                      ),
                      child: Text(
                        '$v',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: value == v ? Colors.white : GlowColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: GlowColors.mist,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Оцените кожу сейчас (1 — комфортно / мало, 5 — сильно). '
            'Check-in обновит план и привяжет его к поездке.',
            style: TextStyle(color: GlowColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _scale('Сухость', _dryness, (v) => setState(() => _dryness = v)),
          _scale('Жирность / блеск', _oiliness, (v) => setState(() => _oiliness = v)),
          _scale('Раздражение', _calmness, (v) => setState(() => _calmness = v)),
          _scale('Краснота', _redness, (v) => setState(() => _redness = v)),
          TextField(
            controller: _note,
            enabled: !_loading && _advice == null,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Заметка (необязательно)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: GlowColors.coral)),
          ],
          if (_advice != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GlowColors.line),
              ),
              child: Text(_advice!, style: const TextStyle(height: 1.4)),
            ),
            if (_suggestSos)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Оценки высокие — обновлённый план в ветке SOS.',
                  style: TextStyle(color: GlowColors.coral, fontWeight: FontWeight.w600),
                ),
              ),
          ],
          const SizedBox(height: 20),
          if (_advice == null)
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Отправить check-in'),
            )
          else ...[
            if (_revised != null)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        result: _revised!,
                        cloudCheckId: _revisedId,
                      ),
                    ),
                  );
                },
                child: const Text('Открыть обновлённый план'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Готово'),
            ),
          ],
        ],
      ),
    );
  }
}
