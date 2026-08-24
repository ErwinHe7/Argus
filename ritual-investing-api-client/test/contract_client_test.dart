import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('decodes the session envelope and tolerates future response fields', () {
    final response = SessionResponse.fromJson({
      'data': {
        'contract_version': '1.0.0',
        'server_time': '2026-08-23T12:00:00Z',
        'future_server_field': true,
      },
      'meta': {'request_id': '018f3c2a-4b67-7a89-8abc-1234567890ab'},
    });

    expect(response.data.contractVersion.value, '1.0.0');
    expect(response.data.serverTime, DateTime.utc(2026, 8, 23, 12));
    expect(response.meta.requestId, '018f3c2a-4b67-7a89-8abc-1234567890ab');
  });

  test(
    'uses explicit Auth0 OAuth token storage and an HTTPS default origin',
    () {
      final client = RitualInvestingApiClient();
      client.setOAuthToken('Auth0OAuth', 'access-token');

      final auth = client.dio.interceptors.whereType<OAuthInterceptor>().single;
      expect(auth.tokens['Auth0OAuth'], 'access-token');
      expect(RitualInvestingApiClient.basePath, startsWith('https://'));
    },
  );
}
