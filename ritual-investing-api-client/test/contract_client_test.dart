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
}

class _RecordingAdapter implements HttpClientAdapter {
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
        'data': {'version': 3},
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
