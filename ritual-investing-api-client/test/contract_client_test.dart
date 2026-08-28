import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:test/test.dart';

const requestId = '018f3c2a-4b67-7a89-8abc-1234567890ab';

void main() {
  test('decodes retained response and error envelopes with future fields', () {
    final response = GetAccount200Response.fromJson({
      'data': {'version': 3, 'future_server_field': true},
      'meta': {'request_id': requestId, 'future_meta_field': true},
    });
    expect(response.meta.requestId, requestId);
    expect(response.data, isA<Map<String, dynamic>>());

    final error = GetAccount401Response.fromJson({
      'error': {
        'code': 'unauthorized',
        'field_errors': <Object?>[],
        'message': 'A valid Supabase access token is required.',
        'request_id': requestId,
        'retryable': false,
        'future_error_field': true,
      },
    });
    expect(error.error.code, 'unauthorized');
    expect(error.error.retryable, isFalse);
  });

  test('uses the Supabase Edge base path and bearer token scheme', () async {
    final adapter = _RecordingAdapter();
    final client = RitualInvestingApiClient();
    client.dio.httpClientAdapter = adapter;
    client.setBearerAuth('SupabaseBearer', 'verified-access-token');

    await SessionApi(client.dio).bootstrapSession();

    expect(
      RitualInvestingApiClient.basePath,
      'https://PROJECT_REF.supabase.co/functions/v1/api',
    );
    expect(adapter.requests.single.path, '/v1/session/bootstrap');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, isNull);
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer verified-access-token',
    );
  });

  test('preserves If-Match on retained optimistic mutations', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    await AccountApi(dio).updatePreferences(
      ifMatch: '"v3"',
      updatePreferencesRequest: UpdatePreferencesRequest(
        themeMode: UpdatePreferencesRequestThemeModeEnum.dark,
      ),
    );

    expect(adapter.requests.single.path, '/v1/preferences');
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.headers['if-match'], '"v3"');
    expect(adapter.requests.single.contentType, 'application/json');
  });

  test(
    'binds manual order confirmation to preview and idempotency header',
    () async {
      final adapter = _RecordingAdapter(
        data: {
          'id': '018f3c2a-4b67-7a89-8abc-123456789001',
          'account_id': '018f3c2a-4b67-7a89-8abc-123456789002',
          'operation': 'place',
          'target_order_id': null,
          'order_id': null,
          'state': 'ambiguous',
          'ambiguous': true,
          'created_at': '2026-08-28T12:00:00.000Z',
          'updated_at': '2026-08-28T12:00:01.000Z',
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final response = await BrokerageOrdersApi(dio).placeWebullOrder(
        accountId: '018f3c2a-4b67-7a89-8abc-123456789002',
        idempotencyKey: 'member-device-key-0001',
        confirmPlaceBrokerageOrder: ConfirmPlaceBrokerageOrder(
          confirmed: true,
          previewId: '018f3c2a-4b67-7a89-8abc-123456789003',
          intent: PlaceBrokerageOrderIntent(
            instrumentId: '018f3c2a-4b67-7a89-8abc-123456789004',
            limitPrice: '10.25',
            orderType: PlaceBrokerageOrderIntentOrderTypeEnum.limit,
            quantity: '1',
            side: PlaceBrokerageOrderIntentSideEnum.buy,
            timeInForce: PlaceBrokerageOrderIntentTimeInForceEnum.day,
          ),
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        '/v1/brokerage/accounts/018f3c2a-4b67-7a89-8abc-123456789002/orders',
      );
      expect(
        adapter.requests.single.headers['idempotency-key'],
        'member-device-key-0001',
      );
      expect(adapter.requests.single.data, contains('"confirmed":true'));
      expect(adapter.requests.single.data, contains('"preview_id"'));
      expect(
        response.data?.data.state,
        BrokerageOrderCommandStateEnum.ambiguous,
      );
    },
  );

  test(
    'requests an atomic provider-authoritative order list refresh',
    () async {
      final adapter = _RecordingAdapter(
        data: {
          'account_id': '018f3c2a-4b67-7a89-8abc-123456789002',
          'state': 'empty',
          'provider_observed_at': '2026-08-28T12:00:00.000Z',
          'fetched_at': '2026-08-28T12:00:01.000Z',
          'expires_at': '2026-08-28T12:01:01.000Z',
          'orders': <Object?>[],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      await BrokerageOrdersApi(dio).listWebullOrders(
        accountId: '018f3c2a-4b67-7a89-8abc-123456789002',
        refresh: 'true',
      );

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.queryParameters['refresh'], 'true');
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.data = const {'version': 3}});

  final Map<String, Object?> data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'data': data,
        'meta': {'request_id': requestId},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
