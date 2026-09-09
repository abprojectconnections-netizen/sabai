import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<String> login({required String email, required String password}) async {
    final Map<String, dynamic> response =
        await _client.post('/auth/login', {'email': email, 'password': password});
    final Object? data = response['data'];
    if (data is! Map<String, dynamic> || data['access_token'] is! String) {
      throw const ApiException('Invalid login response');
    }
    return data['access_token'] as String;
  }
}
