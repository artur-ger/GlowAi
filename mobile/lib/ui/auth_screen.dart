import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/auth_api.dart';
import 'widgets/legal_links.dart';

enum _AuthPhase { login, register, verify, forgot, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _api = AuthApi();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();

  _AuthPhase _phase = _AuthPhase.login;
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  bool _loading = false;
  String? _error;
  String? _hint;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _title => switch (_phase) {
        _AuthPhase.login => 'Вход',
        _AuthPhase.register => 'Регистрация',
        _AuthPhase.verify => 'Подтверждение email',
        _AuthPhase.forgot => 'Сброс пароля',
        _AuthPhase.reset => 'Новый пароль',
      };

  String _detailFromDio(DioException e) {
    final detail = e.response?.data;
    if (detail is Map && detail['detail'] != null) {
      final d = detail['detail'];
      if (d is String) return d;
      return '$d';
    }
    return 'Не удалось выполнить запрос. Проверьте данные и backend.';
  }

  void _applyPending(RegisterPending pending, {_AuthPhase next = _AuthPhase.verify}) {
    setState(() {
      _phase = next;
      _hint = pending.devVerifyCode != null
          ? '${pending.message}\n\nПилотный код: ${pending.devVerifyCode}'
          : pending.message;
      if (pending.devVerifyCode != null) {
        _code.text = pending.devVerifyCode!;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _hint = null;
    });
    try {
      switch (_phase) {
        case _AuthPhase.verify:
          await _api.verifyEmail(email: _email.text.trim(), code: _code.text.trim());
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;
        case _AuthPhase.register:
          if (!_acceptTerms) {
            setState(() => _error = 'Примите условия использования и политику ПДн.');
            return;
          }
          final pending = await _api.register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            acceptTerms: _acceptTerms,
          );
          if (!mounted) return;
          _applyPending(pending);
          return;
        case _AuthPhase.forgot:
          final pending = await _api.forgotPassword(email: _email.text.trim());
          if (!mounted) return;
          _applyPending(pending, next: _AuthPhase.reset);
          return;
        case _AuthPhase.reset:
          await _api.resetPassword(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _password.text,
          );
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;
        case _AuthPhase.login:
          await _api.login(email: _email.text.trim(), password: _password.text);
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;
      }
    } on DioException catch (e) {
      final msg = _detailFromDio(e);
      setState(() {
        _error = msg;
        if (e.response?.statusCode == 403 && msg.toLowerCase().contains('email')) {
          _phase = _AuthPhase.verify;
          _hint = 'Сначала подтвердите email кодом.';
        }
      });
    } catch (_) {
      setState(() => _error = 'Не удалось выполнить запрос. Проверьте данные и backend.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await _api.resendCode(email: _email.text.trim());
      if (!mounted) return;
      _applyPending(pending);
    } on DioException catch (e) {
      setState(() => _error = _detailFromDio(e));
    } catch (_) {
      setState(() => _error = 'Не удалось отправить код.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _primaryLabel => switch (_phase) {
        _AuthPhase.verify => 'Подтвердить email',
        _AuthPhase.register => 'Создать аккаунт',
        _AuthPhase.forgot => 'Отправить код сброса',
        _AuthPhase.reset => 'Сохранить пароль',
        _AuthPhase.login => 'Войти',
      };

  @override
  Widget build(BuildContext context) {
    final showPassword = _phase == _AuthPhase.login ||
        _phase == _AuthPhase.register ||
        _phase == _AuthPhase.reset;
    final showCode = _phase == _AuthPhase.verify || _phase == _AuthPhase.reset;

    return Scaffold(
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: GlowColors.mist,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            switch (_phase) {
              _AuthPhase.verify =>
                'Введите код подтверждения (в пилоте без SMTP код показывается на экране).',
              _AuthPhase.forgot => 'Укажите email — пришлём код для нового пароля.',
              _AuthPhase.reset => 'Введите код из письма и новый пароль.',
              _ =>
                'Аккаунт нужен, чтобы сохранять проверки и обсуждать состояние кожи в чате follow-up.',
            },
            style: const TextStyle(color: GlowColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (_phase == _AuthPhase.register) ...[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Имя'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            enabled: !(_phase == _AuthPhase.verify || _phase == _AuthPhase.reset) ||
                _email.text.isEmpty,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          if (showPassword) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: _phase == _AuthPhase.reset ? 'Новый пароль (мин. 6)' : 'Пароль (мин. 6)',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
          ],
          if (showCode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: _phase == _AuthPhase.reset ? 'Код сброса' : 'Код подтверждения',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
          ],
          if (_phase == _AuthPhase.register) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Принимаю условия и политику ПДн',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                  SizedBox(height: 4),
                  LegalLinks(),
                ],
              ),
            ),
          ],
          if (_hint != null) ...[
            const SizedBox(height: 12),
            Text(_hint!, style: const TextStyle(color: GlowColors.seaDeep, height: 1.35)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: GlowColors.coral)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_primaryLabel),
          ),
          if (_phase == _AuthPhase.verify)
            TextButton(
              onPressed: _loading ? null : _resend,
              child: const Text('Отправить код ещё раз'),
            ),
          if (_phase == _AuthPhase.login) ...[
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _phase = _AuthPhase.forgot;
                        _error = null;
                        _hint = null;
                        _code.clear();
                      }),
              child: const Text('Забыли пароль?'),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _phase = _AuthPhase.register;
                        _error = null;
                        _hint = null;
                      }),
              child: const Text('Нет аккаунта — регистрация'),
            ),
          ],
          if (_phase == _AuthPhase.register)
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _phase = _AuthPhase.login;
                        _error = null;
                        _hint = null;
                      }),
              child: const Text('Уже есть аккаунт — войти'),
            ),
          if (_phase == _AuthPhase.verify ||
              _phase == _AuthPhase.forgot ||
              _phase == _AuthPhase.reset)
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _phase = _AuthPhase.login;
                        _error = null;
                        _hint = null;
                        _code.clear();
                      }),
              child: const Text('Назад ко входу'),
            ),
        ],
      ),
    );
  }
}
