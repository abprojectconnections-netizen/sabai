import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('development defaults to the mock API', () {
      final c = AppConfig.parse(const {});
      expect(c.appEnv, AppEnv.development);
      expect(c.apiMode, ApiMode.mock);
      expect(c.apiBaseUrl, '');
    });

    test('beta must choose its API mode explicitly', () {
      expect(() => AppConfig.parse(const {'APP_ENV': 'beta'}), throwsA(isA<ConfigError>()));
    });

    test('beta with a base url trims trailing slashes', () {
      final c = AppConfig.parse(const {
        'APP_ENV': 'beta',
        'API_MODE': 'beta',
        'API_BASE_URL': 'https://beta.example.com//',
      });
      expect(c.apiBaseUrl, 'https://beta.example.com');
    });

    test('production rejects mock, beta mode, http and localhost', () {
      for (final env in [
        {'APP_ENV': 'production', 'API_MODE': 'mock'},
        {'APP_ENV': 'production', 'API_MODE': 'beta', 'API_BASE_URL': 'https://x.example.com'},
        {'APP_ENV': 'production', 'API_MODE': 'production', 'API_BASE_URL': 'http://x.example.com'},
        {'APP_ENV': 'production', 'API_MODE': 'production', 'API_BASE_URL': 'https://localhost'},
      ]) {
        expect(() => AppConfig.parse(env), throwsA(isA<ConfigError>()), reason: '$env');
      }
    });

    test('non-production never targets the production API', () {
      expect(
        () => AppConfig.parse(const {
          'APP_ENV': 'development',
          'API_MODE': 'production',
          'API_BASE_URL': 'https://api.example.com',
        }),
        throwsA(isA<ConfigError>()),
      );
    });

    test('production with https is accepted', () {
      final c = AppConfig.parse(const {
        'APP_ENV': 'production',
        'API_MODE': 'production',
        'API_BASE_URL': 'https://api.example.com',
      });
      expect(c.isProduction, isTrue);
    });

    test('unknown values are reported', () {
      expect(() => AppConfig.parse(const {'APP_ENV': 'staging'}), throwsA(isA<ConfigError>()));
    });
  });
}
