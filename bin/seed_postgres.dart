import 'dart:io';
import 'package:travel_app_flutter_app/database/postgres_seed.dart';

void printUsage() {
  print('Usage: dart bin/seed_postgres.dart [--host HOST] [--port PORT] [--db DB] [--user USER] [--pass PASS] [--ssl]');
}

Future<void> main(List<String> args) async {
  String host = Platform.environment['PG_HOST'] ?? '127.0.0.1';
  int port = int.tryParse(Platform.environment['PG_PORT'] ?? '5432') ?? 5432;
  String db = Platform.environment['PG_DB'] ?? 'apptravel';
  String user = Platform.environment['PG_USER'] ?? 'postgres';
  String pass = Platform.environment['PG_PASS'] ?? '123456';
  var useSSL = false;

  for (var i = 0; i < args.length; i++) {
    final String a = args[i];
    if (a == '--host' && i + 1 < args.length) {
      host = args[++i];
    } else if (a == '--port' && i + 1 < args.length) port = int.tryParse(args[++i]) ?? port;
    else if (a == '--db' && i + 1 < args.length) db = args[++i];
    else if (a == '--user' && i + 1 < args.length) user = args[++i];
    else if (a == '--pass' && i + 1 < args.length) pass = args[++i];
    else if (a == '--ssl') useSSL = true;
    else if (a == '--help' || a == '-h') {
      printUsage();
      return;
    }
  }

  print('Seeding PostgreSQL at $host:$port database="$db" user="$user"');
  try {
    await seedPostgres(host: host, port: port, database: db, username: user, password: pass, useSSL: useSSL);
    print('Postgres seed completed successfully.');
  } catch (e, st) {
    stderr.writeln('Error seeding Postgres: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}
