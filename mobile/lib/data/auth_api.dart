import 'package:dio/dio.dart';

import '../core/config.dart';
import 'app_sync.dart';
import 'auth_store.dart';

class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.emailVerified = false,
  });

  final int id;
  final String email;
  final String displayName;
  final bool emailVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        emailVerified: json['email_verified'] as bool? ?? false,
      );
}

class RegisterPending {
  RegisterPending({
    required this.email,
    required this.message,
    this.devVerifyCode,
    this.emailSent = false,
  });

  final String email;
  final String message;
  final String? devVerifyCode;
  final bool emailSent;

  factory RegisterPending.fromJson(Map<String, dynamic> json) => RegisterPending(
        email: json['email'] as String? ?? '',
        message: json['message'] as String? ?? '',
        devVerifyCode: json['dev_verify_code'] as String?,
        emailSent: json['email_sent'] as bool? ?? false,
      );
}

class AuthApi {
  AuthApi({Dio? dio, AuthStore? store})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ),
        _store = store ?? AuthStore();

  final Dio _dio;
  final AuthStore _store;

  Future<RegisterPending> register({
    required String email,
    required String password,
    String displayName = '',
    bool acceptTerms = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
        'accept_terms': acceptTerms,
      },
    );
    return RegisterPending.fromJson(response.data!);
  }

  Future<AuthUser> verifyEmail({required String email, required String code}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/verify-email',
      data: {'email': email, 'code': code},
    );
    return _persist(response.data!);
  }

  Future<RegisterPending> resendCode({required String email}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/resend-code',
      data: {'email': email},
    );
    return RegisterPending.fromJson(response.data!);
  }

  Future<RegisterPending> forgotPassword({required String email}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/forgot-password',
      data: {'email': email},
    );
    return RegisterPending.fromJson(response.data!);
  }

  Future<AuthUser> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/reset-password',
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      },
    );
    return _persist(response.data!);
  }

  Future<AuthUser> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _persist(response.data!);
  }

  Future<AuthUser> me() async {
    final token = await _store.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('not logged in');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AuthUser.fromJson(response.data!);
  }

  Future<void> deleteAccount() async {
    final token = await _store.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('not logged in');
    }
    await _dio.delete<void>(
      '/api/v1/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await _store.clear();
    AppSync.instance.sessionChanged();
  }

  Future<void> logout() async {
    await _store.clear();
    AppSync.instance.sessionChanged();
  }

  Future<AuthUser> _persist(Map<String, dynamic> data) async {
    final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    final token = data['access_token'] as String;
    await _store.saveSession(
      token: token,
      email: user.email,
      displayName: user.displayName,
    );
    AppSync.instance.sessionChanged();
    return user;
  }
}
