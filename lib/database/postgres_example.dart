import 'postgres_service.dart';

/// Example usage of [PostgresService].
///
/// Adjust `host`, `port`, `database`, `username`, and `password` to match
/// your PostgreSQL server configuration.
Future<void> runPostgresExample() async {
  final service = PostgresService(
    host: '127.0.0.1',
    port: 5432,
    database: 'apptravel',
    username: 'postgres',
    password: '123456',
  );

  await service.open();
  try {
    final result = await service.mappedQuery(
      'SELECT id, name, description FROM destinations LIMIT 10',
    );

    for (final row in result) {
      final data = row.values.first;
      print('Destination: ${data['name']} - ${data['description']}');
    }
  } finally {
    await service.close();
  }
}
