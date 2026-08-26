import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/config/runtime_config.dart';

void main() {
  test('production configuration requires HTTPS API values and nonempty Auth0 identity', () {
    expect(
      () => RuntimeConfig(
        apiBaseUrl: 'http://api.example',
        auth0Domain: 'tenant.auth0.com',
        auth0ClientId: 'client',
        auth0Audience: 'https://audience',
      ),
      throwsA(isA<RuntimeConfigException>()),
    );
    expect(
      () => RuntimeConfig(
        apiBaseUrl: 'https://api.example',
        auth0Domain: ' ',
        auth0ClientId: 'client',
        auth0Audience: 'https://audience',
      ),
      throwsA(isA<RuntimeConfigException>()),
    );
    final value = RuntimeConfig(
      apiBaseUrl: 'https://api.example',
      auth0Domain: 'tenant.auth0.com',
      auth0ClientId: 'client',
      auth0Audience: 'https://audience',
    );
    expect(value.auth0Domain, 'tenant.auth0.com');
  });
}
