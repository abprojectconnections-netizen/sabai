import 'package:postgres/postgres.dart';

/// A simple PostgreSQL service for Dart VM platforms (mobile/desktop).
///
/// Note: the `postgres` package is not supported on Flutter Web. Do not import
/// this file from code that must compile for Chrome/web.
class PostgresService {

  PostgresService({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    bool useSSL = false,
  }) : _connection = PostgreSQLConnection(
          host,
          port,
          database,
          username: username,
          password: password,
          useSSL: useSSL,
        );
  final PostgreSQLConnection _connection;

  Future<void> open() async {
    if (_connection.isClosed) {
      await _connection.open();
    }
  }

  Future<void> close() async {
    if (!_connection.isClosed) {
      await _connection.close();
    }
  }

  Future<List<List<dynamic>>> query(
    String sql, {
    Map<String, dynamic> substitutionValues = const {},
  }) async {
    return await _connection.query(
      sql,
      substitutionValues: substitutionValues,
    );
  }

  Future<List<Map<String, Map<String, dynamic>>>> mappedQuery(
    String sql, {
    Map<String, dynamic> substitutionValues = const {},
  }) async {
    return await _connection.mappedResultsQuery(
      sql,
      substitutionValues: substitutionValues,
    );
  }

  bool get isOpen => !_connection.isClosed;
}
