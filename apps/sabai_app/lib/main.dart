import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/data/repositories/app_repository.dart';
import 'src/data/repositories/http_repository.dart';
import 'src/data/repositories/mock_repository.dart';
import 'src/features/config/config_error_screen.dart';

  WidgetsFlutterBinding.ensureInitialized();
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigError catch (e) {
    // Invalid configuration fails safely: never start against an unintended backend.
    runApp(ConfigErrorApp(problems: e.problems));
    return;
  }
  final AppRepository repository = config.apiMode == ApiMode.mock
      ? MockRepository()
      : HttpRepository(
          client: http.Client(),
          baseUrl: config.apiBaseUrl,
          mode: config.apiMode,
        );
}
