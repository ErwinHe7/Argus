import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  test('decodes every mixed Discover and Search result independently', () {
    final payloads = <String, Map<String, dynamic>>{
      'asset': {'asset': _assetSummary()},
      'coven': {'coven': _covenSummary()},
      'grimoire': {'grimoire': _grimoireSummary()},
      'circle_template': {'circle_template': _circleTemplateSummary()},
    };

    for (final entry in payloads.entries) {
      final json = <String, dynamic>{'kind': entry.key, ...entry.value};
      final discover = DiscoverItem.fromJson(json);
      final search = SearchResult.fromJson(json);
      expect(discover.kind.value, entry.key);
      expect(search.kind.value, entry.key);
      expect(
        [
          discover.asset,
          discover.coven,
          discover.grimoire,
          discover.circleTemplate,
        ].where((value) => value != null),
        hasLength(1),
      );
      expect(
        [
          search.asset,
          search.coven,
          search.grimoire,
          search.circleTemplate,
        ].where((value) => value != null),
        hasLength(1),
      );
    }

    final future = DiscoverItem.fromJson({'kind': 'future_result'});
    expect(future.kind, DiscoverItemKindEnum.unknownDefaultOpenApi);
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

  test(
    'sends media bytes raw and receives privacy archives as bytes',
    () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final upload = MultipartFile.fromBytes([0xff, 0xd8, 0xff, 0xd9]);

      await AdminMediaApi(dio).uploadMediaQuarantineContent(
        mediaId: '018f3c2a-4b67-7a89-8abc-1234567890ab',
        body: upload,
      );

      expect(adapter.requests.single.data, same(upload));
      expect(adapter.requests.single.data, isNot(isA<String>()));
      expect(adapter.requests.single.contentType, 'application/octet-stream');

      final archive = await PrivacyApi(dio).downloadPrivacyExport(
        requestId: '018f3c2a-4b67-7a89-8abc-1234567890ab',
        token: 'a' * 64,
      );
      expect(archive.data, Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]));
      expect(adapter.requests.last.responseType, ResponseType.bytes);
    },
  );
}

Map<String, dynamic> _demo() => {
  'is_demo': true,
  'limitations': ['Illustrative fixture only.'],
  'observed_at': '2026-08-24T12:00:00Z',
  'source_label': 'Ritual fixture',
};

Map<String, dynamic> _assetSummary() => {
  'appearance_reason': 'Durable research example.',
  'asset_type': 'etf',
  'currency': 'USD',
  'demo': _demo(),
  'id': '018f3c2a-4b67-7a89-8abc-1234567890ab',
  'name': 'Quiet Fund',
  'revision_id': '018f3c2a-4b67-7a89-8abc-1234567890ac',
  'slug': 'quiet-fund',
  'symbol': 'QUIET',
};

Map<String, dynamic> _covenSummary() => {
  'category': 'founder',
  'company': 'Quiet Company',
  'demo': _demo(),
  'effective_date': '2026-01-01',
  'focus': 'Durable systems',
  'id': '018f3c2a-4b67-7a89-8abc-1234567890ad',
  'revision_id': '018f3c2a-4b67-7a89-8abc-1234567890ae',
  'slug': 'quiet-company',
  'symbol': 'QCO',
  'teaser': 'A dated fictional qualification.',
  'verified_as_of': '2026-08-20',
};

Map<String, dynamic> _grimoireSummary() => {
  'curator_label': 'Ritual Research',
  'demo': _demo(),
  'description': 'Durability over drama.',
  'id': '018f3c2a-4b67-7a89-8abc-1234567890af',
  'revision_id': '018f3c2a-4b67-7a89-8abc-1234567890b0',
  'slug': 'quiet-power',
  'theme': 'durability',
  'title': 'Quiet Power',
};

Map<String, dynamic> _circleTemplateSummary() => {
  'creator': {
    'bio': 'A fictional curator.',
    'demo': _demo(),
    'display_name': 'Selene Vale',
    'id': '018f3c2a-4b67-7a89-8abc-1234567890b1',
    'is_fictional': true,
    'slug': 'selene-vale',
  },
  'demo': _demo(),
  'description': 'A fictional demo circle.',
  'id': '018f3c2a-4b67-7a89-8abc-1234567890b2',
  'revision_id': '018f3c2a-4b67-7a89-8abc-1234567890b3',
  'slug': 'soft-power',
  'theme': 'soft_power',
  'title': 'Soft Power',
};

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return options.path.contains('/download')
        ? ResponseBody.fromBytes(
            [0x50, 0x4b, 0x03, 0x04],
            200,
            headers: {
              Headers.contentTypeHeader: ['application/zip'],
            },
          )
        : ResponseBody.fromBytes([], 204);
  }

  @override
  void close({bool force = false}) {}
}
