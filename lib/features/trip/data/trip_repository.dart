import '../../../core/network/api_client.dart';

class TripRepository {
  TripRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> create({required String name, String? destinationId}) async {
    final Map<String, dynamic> response = await _client
        .post('/trips', {'name': name, if (destinationId != null) 'destination_id': destinationId});
    final Object? data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid trip response');
    }
    return data;
  }
}
