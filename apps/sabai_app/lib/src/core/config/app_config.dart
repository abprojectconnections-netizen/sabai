/// Runtime configuration, passed at build time with `--dart-define`:
///
///   flutter run --dart-define=APP_ENV=beta --dart-define=API_MODE=beta \
///     --dart-define=API_BASE_URL=https://beta-api.example.com
///
/// Rules (same as the web prototype, docs/04-environments-and-release.md):
///  * development may use the mock repository or a beta API, never production;
///  * beta may use the mock repository or a beta API, never production;
///  * production must use the production API over https, never mock or localhost.
/// This client-side flag is NOT a security boundary: the backend enforces authorization.
library;

enum AppEnv { development, beta, production }

enum ApiMode { mock, beta, production }

class ConfigError implements Exception {
  ConfigError(this.problems);
  final List<String> problems;

  @override
  String toString() => 'Invalid configuration:\n- ${problems.join('\n- ')}';
}

class AppConfig {
  const AppConfig({
    required this.appEnv,
    required this.apiMode,
    required this.apiBaseUrl,
  });

  final AppEnv appEnv;
  final ApiMode apiMode;
  final String apiBaseUrl;

  bool get isProduction => appEnv == AppEnv.production;

  factory AppConfig.fromEnvironment() => AppConfig.parse(const {
        'APP_ENV': String.fromEnvironment('APP_ENV'),
        'API_MODE': String.fromEnvironment('API_MODE'),
        'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
      });

  /// Pure parser (unit-tested). Throws [ConfigError] listing every problem.
  factory AppConfig.parse(Map<String, String> env) {
    final problems = <String>[];
    final envName = (env['APP_ENV'] ?? '').trim();
    final modeName = (env['API_MODE'] ?? '').trim();

    final appEnv = envName.isEmpty
        ? AppEnv.development
        : AppEnv.values.asNameMap()[envName];
    if (appEnv == null) {
      problems.add(
          'APP_ENV must be one of ${AppEnv.values.map((e) => e.name).join(', ')} (got "$envName")');
    }

    // Only development defaults to mock; beta/production must choose explicitly.
    final effectiveMode =
        modeName.isEmpty && appEnv == AppEnv.development ? 'mock' : modeName;
    final apiMode = ApiMode.values.asNameMap()[effectiveMode];
    if (apiMode == null) {
      problems.add(
          'API_MODE must be one of ${ApiMode.values.map((e) => e.name).join(', ')} (got "${effectiveMode.isEmpty ? 'unset' : effectiveMode}")');
    }

    var baseUrl = '';
    if (apiMode != null && apiMode != ApiMode.mock) {
      final raw = (env['API_BASE_URL'] ?? '').trim();
      if (raw.isEmpty) {
        problems.add('API_BASE_URL is required when API_MODE=${apiMode.name}');
      } else {
        final uri = Uri.tryParse(raw);
        final ok = uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty;
        if (!ok) {
          problems.add('API_BASE_URL is not a valid http(s) URL (got "$raw")');
        } else {
          baseUrl = raw.replaceAll(RegExp(r'/+$'), '');
          if (appEnv == AppEnv.production) {
            if (uri.scheme != 'https') {
              problems.add('Production API URL must use https');
            }
            const local = {'localhost', '127.0.0.1', '::1', '0.0.0.0'};
            if (local.contains(uri.host)) {
              problems.add('Production API URL must not point at localhost');
            }
          }
        }
      }
    }

    if (appEnv == AppEnv.production && apiMode == ApiMode.mock) {
      problems.add('Production must not run with the mock API');
    }
    if (appEnv == AppEnv.production && apiMode == ApiMode.beta) {
      problems.add('Production must use API_MODE=production');
    }
    if (appEnv != null &&
        appEnv != AppEnv.production &&
        apiMode == ApiMode.production) {
      problems.add('${appEnv.name} must never target the production API');
    }

    if (problems.isNotEmpty) throw ConfigError(problems);
    return AppConfig(appEnv: appEnv!, apiMode: apiMode!, apiBaseUrl: baseUrl);
  }
}
