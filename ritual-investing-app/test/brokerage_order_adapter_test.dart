import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/features/orders/data/generated_brokerage_order_api_service.dart';
import 'package:ritual_investing_app/features/orders/domain/brokerage_model.dart';

void main() {
  test(
    'generated adapter rejects a cross-account response as invalid',
    () async {
      final client = RitualInvestingApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://argus.invalid'))
          ..httpClientAdapter = _OrderAdapter(),
      );
      final service = GeneratedBrokerageOrderApiService(client);

      await expectLater(
        service.list('account-a'),
        throwsA(
          isA<BrokerageOrderFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                BrokerageOrderFailureReason.invalid,
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('not supported'),
              ),
        ),
      );
    },
  );

  test('generated adapter rejects a malformed preview contract', () async {
    final client = RitualInvestingApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://argus.invalid'))
        ..httpClientAdapter = _MalformedPreviewAdapter(),
    );
    final service = GeneratedBrokerageOrderApiService(client);

    await expectLater(
      service.previewPlace(
        'account-a',
        const BrokeragePlaceOrderIntent(
          instrumentId: 'instrument-a',
          symbol: 'ARG',
          side: BrokerageOrderSide.buy,
          orderType: BrokerageOrderType.market,
          quantity: '1',
          timeInForce: BrokerageTimeInForce.day,
        ),
      ),
      throwsA(
        isA<BrokerageOrderFailure>().having(
          (failure) => failure.reason,
          'reason',
          BrokerageOrderFailureReason.invalid,
        ),
      ),
    );
  });
}

class _OrderAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'data': {
        'account_id': 'account-b',
        'state': 'empty',
        'provider_observed_at': null,
        'fetched_at': '2026-08-28T12:00:00.000Z',
        'expires_at': '2026-08-28T12:05:00.000Z',
        'orders': <Object>[],
      },
      'meta': {'request_id': 'request-u9'},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _MalformedPreviewAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'data': {
        'account_id': 'account-a',
        'capability_version': 3,
        'currency': 'USD',
        'estimated_total': '100',
        'expires_at': '2026-08-28T12:05:00.000Z',
        'id': 'preview-a',
        'operation': 'place',
        'policy_version': 'webull-manual-v1',
        'restriction_generation': 4,
        'reviewed_payload_hash': 'UPPERCASE-OR-TOO-SHORT',
        'target_order_id': null,
      },
      'meta': {'request_id': 'request-u9'},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
