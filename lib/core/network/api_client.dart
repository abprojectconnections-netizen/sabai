import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final http.Response response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final Map<String, dynamic> payload = _decodeEnvelope(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(payload));
    }
    return payload;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final http.Response response = await _client.get(Uri.parse('${AppConfig.apiBaseUrl}$path'));
    final Map<String, dynamic> payload = _decodeEnvelope(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(payload));
    }
    return payload;
  }

  @visibleForTesting
  void dispose() => _client.close();

  Map<String, dynamic> _decodeEnvelope(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Invalid response from server');
    }
    return decoded;
  }

  String _errorMessage(Map<String, dynamic> payload) {
    final Object? error = payload['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return 'Request failed';
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
