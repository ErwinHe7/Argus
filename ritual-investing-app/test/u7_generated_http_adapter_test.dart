import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/orders/data/generated_simulated_investing_api_service.dart';
import 'package:ritual_investing_app/features/orders/domain/model.dart';
import 'package:ritual_investing_app/features/rebalancing/domain/model.dart';
import 'package:ritual_investing_app/features/recurring/domain/model.dart';

void main() {
  test(
    'U7 generated Dio adapters serialize exact provider-free contracts',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final client = RitualInvestingApiClient(
        basePathOverride: harness.baseUrl,
        interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
      );
      final orders = GeneratedOrderApiService(client);
      final recurring = GeneratedRecurringPlanApiService(client);
      final rebalancing = GeneratedRebalanceApiService(client);

      final orderPreview = await orders.preview(
        const OrderDraft.notional(
          portfolioId: _portfolioId,
          assetId: _assetId,
          side: OrderSide.buy,
          minorUnits: 2500,
        ),
      );
      final orderReceipt = await orders.commit(
        const OrderCommit(
          portfolioId: _portfolioId,
          previewId: _orderPreviewId,
          portfolioVersion: 8,
          idempotencyKey: 'order-command-key-0001',
        ),
      );
      final orderList = await orders.list(_portfolioId);
      final orderDetail = await orders.get(_orderId);

      final plans = await recurring.list(_portfolioId);
      final plan = await recurring.get(_planId);
      final created = await recurring.create(
        RecurringPlanCreate(
          draft: RecurringPlanDraft(
            portfolioId: _portfolioId,
            sourceId: _sourceId,
            type: RecurringType.allocation,
            amountMinor: 4200,
            frequency: RecurringFrequency.monthly,
            firstRunAt: DateTime.parse('2026-09-01T09:30:00-04:00'),
            allocations: const [
              RecurringAllocation(assetId: _assetId, weightBps: 10000),
            ],
          ),
          idempotencyKey: 'recurring-key-000001',
        ),
      );
      await recurring.edit(
        const RecurringPlanEdit(
          planId: _planId,
          expectedVersion: 3,
          amountMinor: 5000,
          frequency: RecurringFrequency.weekly,
          allocations: [
            RecurringAllocation(assetId: _assetId, weightBps: 10000),
          ],
        ),
      );
      await recurring.pause(_planId, 4);
      await recurring.resume(_planId, 5);
      await recurring.cancel(_planId, 6);

      final rebalancePreview = await rebalancing.preview(_portfolioId, const [
        RebalanceAllocation(assetId: _assetId, targetBps: 10000),
      ]);
      final rebalanceReceipt = await rebalancing.commit(
        const RebalanceCommit(
          portfolioId: _portfolioId,
          previewId: _rebalancePreviewId,
          portfolioVersion: 8,
          idempotencyKey: 'rebalance-key-000001',
        ),
      );

      expect(orderPreview.symbol, 'QPW');
      expect(orderReceipt.ledgerTransactionIds, [_transactionId]);
      expect(orderList.single.id, _orderId);
      expect(orderDetail.fill?.priceMinor, 2000);
      expect(plans.single.id, _planId);
      expect(plan.version, 3);
      expect(created.portfolioId, _portfolioId);
      expect(rebalancePreview.trades.single.notionalMinor, 2500);
      expect(rebalanceReceipt.commandId, _rebalanceCommandId);
      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u7-member-token',
        ),
        isTrue,
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/order-previews')
            .body,
        {
          'asset_id': _assetId,
          'side': 'buy',
          'notional': {'currency': 'USD', 'minor_units': 2500},
        },
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/orders')
            .idempotencyKey,
        'order-command-key-0001',
      );
      expect(
        harness.single('POST', '/v1/portfolios/$_portfolioId/orders').body,
        {'preview_id': _orderPreviewId, 'portfolio_version': 8},
      );
      expect(
        harness.single('GET', '/v1/orders').query['portfolio_id'],
        _portfolioId,
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/recurring-plans')
            .body,
        {
          'type': 'allocation',
          'amount': {'currency': 'USD', 'minor_units': 4200},
          'frequency': 'monthly',
          'source_id': _sourceId,
          'allocations': [
            {'asset_id': _assetId, 'weight_bps': 10000},
          ],
          'first_run_at': '2026-09-01T13:30:00.000Z',
        },
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/recurring-plans')
            .idempotencyKey,
        'recurring-key-000001',
      );
      expect(
        harness.single('PATCH', '/v1/recurring-plans/$_planId').ifMatch,
        '"v3"',
      );
      expect(harness.single('PATCH', '/v1/recurring-plans/$_planId').body, {
        'amount': {'currency': 'USD', 'minor_units': 5000},
        'frequency': 'weekly',
        'allocations': [
          {'asset_id': _assetId, 'weight_bps': 10000},
        ],
      });
      expect(
        harness.single('POST', '/v1/recurring-plans/$_planId/pause').ifMatch,
        '"v4"',
      );
      expect(
        harness.single('POST', '/v1/recurring-plans/$_planId/resume').ifMatch,
        '"v5"',
      );
      expect(
        harness.single('DELETE', '/v1/recurring-plans/$_planId').ifMatch,
        '"v6"',
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/rebalance-previews')
            .body,
        {
          'target_allocation': [
            {'asset_id': _assetId, 'target_bps': 10000},
          ],
        },
      );
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/rebalances')
            .idempotencyKey,
        'rebalance-key-000001',
      );
      expect(
        harness.single('POST', '/v1/portfolios/$_portfolioId/rebalances').body,
        {'preview_id': _rebalancePreviewId, 'portfolio_version': 8},
      );
      expect(
        harness.requests.every((request) => request.path.startsWith('/v1/')),
        isTrue,
      );
      expect(
        harness.requests.every(
          (request) => !RegExp(
            r'broker|bank|provider|plaid|alpaca|payment',
            caseSensitive: false,
          ).hasMatch(request.path),
        ),
        isTrue,
      );
    },
  );

  test('malformed generated socket responses fail closed', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final client = RitualInvestingApiClient(basePathOverride: harness.baseUrl);
    final orders = GeneratedOrderApiService(client);
    final recurring = GeneratedRecurringPlanApiService(client);
    final rebalancing = GeneratedRebalanceApiService(client);

    for (final mode in [
      _Mode.orderWrongPortfolio,
      _Mode.orderMissingAcceptedFill,
      _Mode.notDemo,
      _Mode.unknownCurrency,
    ]) {
      harness.mode = mode;
      await expectLater(
        mode == _Mode.orderMissingAcceptedFill
            ? orders.list(_portfolioId)
            : orders.preview(
                const OrderDraft.notional(
                  portfolioId: _portfolioId,
                  assetId: _assetId,
                  side: OrderSide.buy,
                  minorUnits: 2500,
                ),
              ),
        throwsA(_terminalFailure),
      );
    }

    harness.mode = _Mode.recurringInvalidAllocations;
    await expectLater(recurring.list(_portfolioId), throwsA(_terminalFailure));
    harness.mode = _Mode.rebalanceInvalidTrade;
    await expectLater(
      rebalancing.preview(_portfolioId, const [
        RebalanceAllocation(assetId: _assetId, targetBps: 10000),
      ]),
      throwsA(_terminalFailure),
    );
  });

  test(
    'generated errors map stale preview and already-balanced exactly',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final client = RitualInvestingApiClient(
        basePathOverride: harness.baseUrl,
      );
      final orders = GeneratedOrderApiService(client);
      final rebalancing = GeneratedRebalanceApiService(client);

      harness.mode = _Mode.previewStale;
      await expectLater(
        orders.commit(
          const OrderCommit(
            portfolioId: _portfolioId,
            previewId: _orderPreviewId,
            portfolioVersion: 8,
            idempotencyKey: 'order-command-key-0001',
          ),
        ),
        throwsA(
          isA<OrderCommitFailure>().having(
            (failure) => failure.reason,
            'reason',
            OrderCommitFailureReason.stalePreview,
          ),
        ),
      );

      harness.mode = _Mode.alreadyBalanced;
      await expectLater(
        rebalancing.preview(_portfolioId, const [
          RebalanceAllocation(assetId: _assetId, targetBps: 10000),
        ]),
        throwsA(isA<RebalanceAlreadyBalanced>()),
      );
    },
  );

  test('recurring version and transition conflicts map exactly', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final recurring = GeneratedRecurringPlanApiService(
      RitualInvestingApiClient(basePathOverride: harness.baseUrl),
    );

    harness.mode = _Mode.versionConflict;
    await expectLater(
      recurring.edit(
        const RecurringPlanEdit(
          planId: _planId,
          expectedVersion: 3,
          amountMinor: 5000,
        ),
      ),
      throwsA(
        isA<RecurringFailure>().having(
          (failure) => failure.reason,
          'reason',
          RecurringFailureReason.conflict,
        ),
      ),
    );

    harness.mode = _Mode.invalidTransition;
    await expectLater(
      recurring.pause(_planId, 3),
      throwsA(
        isA<RecurringFailure>().having(
          (failure) => failure.reason,
          'reason',
          RecurringFailureReason.invalidTransition,
        ),
      ),
    );
  });
}

final _terminalFailure = isA<LoadFailure>().having(
  (failure) => failure.phase,
  'phase',
  LoadPhase.terminalFailure,
);

const _portfolioId = '00000000-0000-4000-8000-000000000701';
const _sourceId = '00000000-0000-4000-8000-000000000702';
const _assetId = '00000000-0000-4000-8000-000000000703';
const _orderPreviewId = '00000000-0000-4000-8000-000000000704';
const _orderId = '00000000-0000-4000-8000-000000000705';
const _orderCommandId = '00000000-0000-4000-8000-000000000706';
const _planId = '00000000-0000-4000-8000-000000000707';
const _runId = '00000000-0000-4000-8000-000000000708';
const _rebalancePreviewId = '00000000-0000-4000-8000-000000000709';
const _rebalanceCommandId = '00000000-0000-4000-8000-000000000710';
const _transactionId = '00000000-0000-4000-8000-000000000711';

enum _Mode {
  normal,
  orderWrongPortfolio,
  orderMissingAcceptedFill,
  recurringInvalidAllocations,
  rebalanceInvalidTrade,
  notDemo,
  unknownCurrency,
  previewStale,
  alreadyBalanced,
  versionConflict,
  invalidTransition,
}

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.query,
    required this.authorization,
    required this.idempotencyKey,
    required this.ifMatch,
    required this.body,
  });
  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final String? idempotencyKey;
  final String? ifMatch;
  final Object? body;
}

class _Harness {
  _Harness._(this.server);
  final HttpServer server;
  final List<_Request> requests = [];
  _Mode mode = _Mode.normal;

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server);
    server.listen(harness._handle);
    return harness;
  }

  String get baseUrl => 'http://${server.address.host}:${server.port}';
  Future<void> close() => server.close(force: true);
  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    requests.add(
      _Request(
        method: request.method,
        path: request.uri.path,
        query: request.uri.queryParameters,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        idempotencyKey: request.headers.value('idempotency-key'),
        ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
        body: text.isEmpty ? null : jsonDecode(text),
      ),
    );
    final path = request.uri.path;
    final method = request.method;

    if (mode == _Mode.previewStale &&
        method == 'POST' &&
        path.endsWith('/orders')) {
      return _error(request.response, 'preview_stale', 409);
    }
    if (mode == _Mode.alreadyBalanced && path.endsWith('/rebalance-previews')) {
      return _error(request.response, 'already_balanced', 409);
    }
    if (mode == _Mode.versionConflict && method == 'PATCH') {
      return _error(request.response, 'version_conflict', 409);
    }
    if (mode == _Mode.invalidTransition && path.endsWith('/pause')) {
      return _error(request.response, 'invalid_transition', 409);
    }
    if (method == 'POST' && path.endsWith('/order-previews')) {
      return _json(request.response, {'data': _orderPreview, 'meta': _meta});
    }
    if (method == 'POST' && path.endsWith('/orders')) {
      return _json(request.response, {'data': _orderReceipt, 'meta': _meta});
    }
    if (method == 'GET' && path == '/v1/orders') {
      return _json(request.response, {
        'data': [_order],
        'meta': _collectionMeta,
      });
    }
    if (method == 'GET' && path == '/v1/orders/$_orderId') {
      return _json(request.response, {'data': _order, 'meta': _meta});
    }
    if (method == 'GET' &&
        path == '/v1/portfolios/$_portfolioId/recurring-plans') {
      return _json(request.response, {
        'data': [_plan],
        'meta': _collectionMeta,
      });
    }
    if (method == 'POST' &&
        path == '/v1/portfolios/$_portfolioId/recurring-plans') {
      return _json(request.response, {'data': _plan, 'meta': _meta}, 201);
    }
    if (method == 'GET' && path == '/v1/recurring-plans/$_planId') {
      return _json(request.response, {'data': _plan, 'meta': _meta});
    }
    if (method == 'PATCH' && path == '/v1/recurring-plans/$_planId') {
      return _json(request.response, {
        'data': {..._plan, 'version': 4},
        'meta': _meta,
      });
    }
    if (method == 'POST' && path == '/v1/recurring-plans/$_planId/pause') {
      return _json(request.response, {
        'data': {..._plan, 'status': 'paused', 'version': 5},
        'meta': _meta,
      });
    }
    if (method == 'POST' && path == '/v1/recurring-plans/$_planId/resume') {
      return _json(request.response, {
        'data': {..._plan, 'version': 6},
        'meta': _meta,
      });
    }
    if (method == 'DELETE' && path == '/v1/recurring-plans/$_planId') {
      return _empty(request.response);
    }
    if (method == 'POST' && path.endsWith('/rebalance-previews')) {
      return _json(request.response, {
        'data': _rebalancePreview,
        'meta': _meta,
      });
    }
    if (method == 'POST' && path.endsWith('/rebalances')) {
      return _json(request.response, {
        'data': _rebalanceReceipt,
        'meta': _meta,
      });
    }
    return _error(request.response, 'resource_not_found', 404);
  }

  Map<String, Object?> get _demo => {
    'is_demo': mode != _Mode.notDemo,
    'observed_at': '2026-08-25T12:00:00.000Z',
    'source_label': 'Deterministic Demo ledger',
    'limitations': ['No real money moves.'],
  };

  Map<String, Object?> get _orderPreview => {
    'id': _orderPreviewId,
    'portfolio_id': mode == _Mode.orderWrongPortfolio
        ? _sourceId
        : _portfolioId,
    'portfolio_version': 8,
    'asset_id': _assetId,
    'symbol': 'QPW',
    'side': 'buy',
    'notional': {
      'currency': mode == _Mode.unknownCurrency ? 'EUR' : 'USD',
      'minor_units': 2500,
    },
    'quantity': {'value': '1.250000', 'scale': 6},
    'frozen_price': {'currency': 'USD', 'minor_units': 2000},
    'quote_snapshot_id': _transactionId,
    'observed_at': '2026-08-25T12:00:00.000Z',
    'expires_at': '2026-08-25T12:15:00.000Z',
    'status': 'active',
    'demo': _demo,
  };

  Map<String, Object?> get _order => {
    'id': _orderId,
    'portfolio_id': _portfolioId,
    'command_id': _orderCommandId,
    'asset_id': _assetId,
    'symbol': 'QPW',
    'side': 'buy',
    'status': 'accepted',
    'notional': {'currency': 'USD', 'minor_units': 2500},
    'quantity': null,
    'fill': mode == _Mode.orderMissingAcceptedFill
        ? null
        : {
            'quantity': {'value': '1.250000', 'scale': 6},
            'price': {'currency': 'USD', 'minor_units': 2000},
            'filled_at': '2026-08-25T12:01:00.000Z',
          },
    'demo': _demo,
  };

  Map<String, Object?> get _plan => {
    'id': _planId,
    'portfolio_id': _portfolioId,
    'type': 'allocation',
    'amount': {'currency': 'USD', 'minor_units': 4200},
    'frequency': 'monthly',
    'next_run_at': '2026-09-01T13:30:00.000Z',
    'status': 'active',
    'allocations': mode == _Mode.recurringInvalidAllocations
        ? [
            {'asset_id': _assetId, 'weight_bps': 5000},
            {'asset_id': _assetId, 'weight_bps': 5000},
          ]
        : [
            {'asset_id': _assetId, 'weight_bps': 10000},
          ],
    'recent_runs': [
      {
        'id': _runId,
        'scheduled_for': '2026-08-01T13:30:00.000Z',
        'status': 'completed',
      },
    ],
    'version': 3,
    'demo': _demo,
  };

  Map<String, Object?> get _rebalancePreview => {
    'id': _rebalancePreviewId,
    'portfolio_id': _portfolioId,
    'portfolio_version': 8,
    'target_allocation': [
      {'asset_id': _assetId, 'target_bps': 10000},
    ],
    'trades': [
      {
        'asset_id': _assetId,
        'side': 'buy',
        'quantity': {'value': '1.250000', 'scale': 6},
        'notional': {
          'currency': 'USD',
          'minor_units': mode == _Mode.rebalanceInvalidTrade ? 0 : 2500,
        },
      },
    ],
    'expires_at': '2026-08-25T12:15:00.000Z',
    'status': 'active',
    'demo': _demo,
  };

  Map<String, Object?> get _orderReceipt => {
    'command_id': _orderCommandId,
    'status': 'committed',
    'portfolio_version': 9,
    'ledger_transaction_ids': [_transactionId],
    'summary': {'kind': 'order'},
    'projection_links': [],
    'demo': _demo,
  };

  Map<String, Object?> get _rebalanceReceipt => {
    ..._orderReceipt,
    'command_id': _rebalanceCommandId,
    'summary': {'kind': 'rebalance'},
  };
}

const _meta = {'request_id': '00000000-0000-4000-8000-000000000712'};
const _collectionMeta = {
  'request_id': '00000000-0000-4000-8000-000000000712',
  'has_more': false,
  'next_cursor': null,
};

Future<void> _error(HttpResponse response, String code, int status) =>
    _json(response, {
      'error': {'code': code, 'message': code},
    }, status);

Future<void> _json(
  HttpResponse response,
  Object body, [
  int status = 200,
]) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

Future<void> _empty(HttpResponse response) async {
  response.statusCode = 204;
  await response.close();
}

class _Token implements AccessTokenProvider {
  const _Token();
  @override
  Future<String?> accessToken() async => 'u7-member-token';
}
