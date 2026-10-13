import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.email,
    required this.displayName,
  });

  final String accessToken;
  final String email;
  final String displayName;
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _defaultBaseUrl = 'http://localhost:8080/api/v1';

  final http.Client _client;

  String get _baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return _defaultBaseUrl;
    return 'http://10.0.2.2:8080/api/v1';
  }

  Future<AuthSession> login({required String email, required String password}) => _send(
        endpoint: 'login',
        payload: {'email': email, 'password': password},
        email: email,
      );

  Future<AuthSession> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      _send(
        endpoint: 'register',
        payload: {
          'display_name': displayName,
          'email': email,
          'password': password,
        },
        email: email,
        displayName: displayName,
      );

  Future<AuthSession> _send({
    required String endpoint,
    required Map<String, String> payload,
    required String email,
    String displayName = '',
  }) async {
    try {
      final http.Response response = await _client
          .post(
            Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/auth/$endpoint'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body['error'] as Map<String, dynamic>?;
        final code = error?['code'] as String?;
        final message = error?['message'] as String?;
        if (endpoint == 'login' && response.statusCode == 401) {
          throw const AuthApiException('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
        }
        if (code == 'VALIDATION_ERROR' && endpoint == 'register') {
          throw const AuthApiException('อีเมลนี้ถูกใช้แล้ว หรือข้อมูลไม่ถูกต้อง');
        }
        throw AuthApiException(message ?? 'ไม่สามารถดำเนินการได้ กรุณาลองอีกครั้ง');
      }

      final data = body['data'] as Map<String, dynamic>?;
      final token = data?['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('ระบบตอบกลับไม่สมบูรณ์ กรุณาลองอีกครั้ง');
      }
      final user = data?['user'] as Map<String, dynamic>?;
      return AuthSession(
        accessToken: token,
        email: email,
        displayName: (user?['display_name'] as String?) ?? displayName,
      );
    } on AuthApiException {
      rethrow;
    } on TimeoutException {
      throw const AuthApiException('เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง');
    } on http.ClientException {
      throw const AuthApiException('ติดต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบการเชื่อมต่อ');
    } on FormatException {
      throw const AuthApiException('เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง');
    } catch (_) {
      throw const AuthApiException('เกิดข้อผิดพลาด กรุณาลองใหม่ภายหลัง');
    }
  }
}
