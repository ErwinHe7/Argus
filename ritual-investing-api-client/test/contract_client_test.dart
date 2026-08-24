import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('decodes an envelope and tolerates future response fields', () {
    final response = HealthResponse.fromJson({
      'data': {
        'build_revision': '8365b1e',
        'status': 'ok',
        'future_server_field': true,
      },
      'meta': {'request_id': '018f3c2a-4b67-7a89-8abc-1234567890ab'},
    });

    expect(response.data.buildRevision, '8365b1e');
    expect(response.data.status, HealthResponseDataStatusEnum.ok);
    expect(response.meta.requestId, '018f3c2a-4b67-7a89-8abc-1234567890ab');
  });

  test('maps a future asset type to the generated unknown enum value', () {
    final asset = AssetSummary.fromJson({
      'appearance_reason': 'Appears in a future catalog revision.',
      'asset_type': 'tokenized_fund',
      'currency': 'USD',
      'demo': {
        'is_demo': true,
        'limitations': ['Illustrative fixture only.'],
        'observed_at': '2026-08-24T12:00:00Z',
        'source_label': 'Ritual fixture',
      },
      'id': '018f3c2a-4b67-7a89-8abc-1234567890ab',
      'name': 'Future Fund',
      'revision_id': '018f3c2a-4b67-7a89-8abc-1234567890ac',
      'slug': 'future-fund',
      'symbol': 'FUTR',
    });

    expect(asset.assetType, AssetSummaryAssetTypeEnum.unknownDefaultOpenApi);
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
