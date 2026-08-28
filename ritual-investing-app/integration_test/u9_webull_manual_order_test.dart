import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';
import 'package:ritual_investing_app/features/orders/application/brokerage_order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/orders/data/generated_brokerage_order_api_service.dart';
import 'package:ritual_investing_app/features/orders/presentation/brokerage_order_screen.dart';
import 'package:ritual_investing_app/features/portfolio/application/brokerage_controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/brokerage_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'generated Webull preview, confirm, and explicit status refresh converge',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);

      final portfolio = BrokeragePortfolioController(
        repository: BrokeragePortfolioRepository(
          service: const _PortfolioService(),
        ),
        initialAccountId: _accountId,
      );
      await portfolio.open(_accountId);
      final orders = BrokerageOrderController(
        repository: BrokerageOrderRepository(
          service: GeneratedBrokerageOrderApiService(harness.client),
        ),
        portfolioController: portfolio,
        pendingStore: PendingCommandStore(storage: _Storage()),
        scope: const CacheScope(accountId: 'u9-member', resetGeneration: 0),
        createKey: () => 'u9-webull-command-key',
        now: () => DateTime.utc(2026, 8, 28, 12),
      );
      addTearDown(portfolio.dispose);
      addTearDown(orders.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: BrokerageOrderScreen(
            accountId: _accountId,
            controller: orders,
            portfolioController: portfolio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('preview-webull-order')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('webull-order-review')), findsOneWidget);
      expect(find.text('Capability version 7'), findsOneWidget);
      expect(find.text('Restriction generation 11'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-webull-order')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Acknowledged, nonterminal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('refresh-webull-command')));
      await tester.pumpAndSettle();
      expect(find.textContaining('place · Resolved'), findsOneWidget);
      expect(orders.selectedOrder?.order.id, _orderId);
      await tester.scrollUntilVisible(
        find.byKey(const Key('webull-order-$_orderId')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Filled at Webull'), findsOneWidget);

      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u9-loopback-token',
        ),
        isTrue,
      );
      final confirmation = harness.requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.path == '/v1/brokerage/accounts/$_accountId/orders',
      );
      expect(confirmation.idempotencyKey, 'u9-webull-command-key');
      expect(confirmation.body, contains('"confirmed":true'));
      expect(confirmation.body, contains('"quantity":"1"'));
      expect(
        harness.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.path == '/v1/brokerage/order-commands/$_commandId',
        ),
        hasLength(1),
      );
    },
  );
}

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.authorization,
    required this.idempotencyKey,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? idempotencyKey;
  final String body;
}

class _Harness {
  _Harness._(this.server, this.client);

  final HttpServer server;
  final RitualInvestingApiClient client;
  final List<_Request> requests = [];
  bool commandConfirmed = false;
  bool commandResolved = false;

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
    );
    final harness = _Harness._(server, client);
    unawaited(harness._serve());
    return harness;
  }

  Future<void> close() async {
    client.dio.close(force: true);
    await server.close(force: true);
  }

  Future<void> _serve() async {
    await for (final request in server) {
      final body = await utf8.decoder.bind(request).join();
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path;
      if (request.method == 'GET' &&
          path == '/v1/brokerage/accounts/$_accountId/orders') {
        _json(request, {
          'data': {
            'account_id': _accountId,
            'state': commandResolved ? 'fresh' : 'empty',
            'provider_observed_at': '2026-08-28T12:00:00.000Z',
            'fetched_at': '2026-08-28T12:00:00.000Z',
            'expires_at': '2026-08-28T12:05:00.000Z',
            'orders': [if (commandResolved) _order],
          },
          'meta': _meta,
        });
      } else if (request.method == 'POST' &&
          path == '/v1/brokerage/accounts/$_accountId/orders/previews') {
        _json(request, {'data': _preview, 'meta': _meta});
      } else if (request.method == 'POST' &&
          path == '/v1/brokerage/accounts/$_accountId/orders') {
        commandConfirmed = true;
        _json(request, {'data': _command('accepted'), 'meta': _meta});
      } else if (request.method == 'GET' &&
          path == '/v1/brokerage/order-commands/$_commandId' &&
          commandConfirmed) {
        commandResolved = true;
        _json(request, {'data': _command('resolved'), 'meta': _meta});
      } else if (request.method == 'GET' &&
          path == '/v1/brokerage/accounts/$_accountId/orders/$_orderId') {
        _json(request, {'data': _orderDetail, 'meta': _meta});
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, {
          'error': {'code': 'resource_not_found', 'message': 'Not found'},
        });
      }
      await request.response.close();
    }
  }

  void _json(HttpRequest request, Object value) =>
      request.response.write(jsonEncode(value));
}

class _PortfolioService implements BrokeragePortfolioService {
  const _PortfolioService();

  @override
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  }) async => BrokeragePortfolioSnapshot(
    accountId: accountId,
    balance: _observation(
      const BrokerageBalanceView(
        currency: 'USD',
        cash: '1000',
        totalEquity: '1000',
      ),
    ),
    positions: _observation(const [
      BrokeragePositionView(
        instrumentId: _instrumentId,
        symbol: 'ARG',
        name: 'Argus test instrument',
        quantity: '1',
        availableQuantity: '1',
        currency: 'USD',
        supported: true,
      ),
    ]),
    capabilities: _observation(const [
      BrokerageCapabilityView(
        kind: BrokerageCapabilityKind.manualOrders,
        available: true,
        providerCode: 'manual_orders',
      ),
    ]),
    restrictions: _observation(const <BrokerageRestrictionView>[]),
  );
}

BrokerageObservation<T> _observation<T>(T value) => BrokerageObservation(
  state: BrokerageResourceState.fresh,
  value: value,
  observedAt: DateTime.utc(2026, 8, 28, 12),
  expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
  reason: null,
);

Map<String, Object?> _command(String state) => {
  'account_id': _accountId,
  'ambiguous': false,
  'created_at': '2026-08-28T12:00:00.000Z',
  'id': _commandId,
  'operation': 'place',
  'order_id': state == 'resolved' ? _orderId : null,
  'state': state,
  'target_order_id': null,
  'updated_at': '2026-08-28T12:00:01.000Z',
};

const _preview = {
  'account_id': _accountId,
  'capability_version': 7,
  'currency': 'USD',
  'estimated_total': '125.25',
  'expires_at': '2026-08-28T12:05:00.000Z',
  'id': _previewId,
  'operation': 'place',
  'policy_version': 'webull-manual-v1',
  'restriction_generation': 11,
  'reviewed_payload_hash':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'target_order_id': null,
};

const _order = {
  'average_fill_price': '125.25',
  'currency': 'USD',
  'filled_quantity': '1',
  'id': _orderId,
  'instrument_id': _instrumentId,
  'limit_price': null,
  'order_type': 'market',
  'provider_order_type': 'MKT',
  'provider_side': 'BUY',
  'provider_state': 'FILLED',
  'provider_time_in_force': 'DAY',
  'quantity': '1',
  'side': 'buy',
  'state': 'filled',
  'stop_price': null,
  'symbol': 'ARG',
  'terminal': true,
  'time_in_force': 'day',
};

const _orderDetail = {
  ..._order,
  'fetched_at': '2026-08-28T12:00:02.000Z',
  'generation': 3,
  'provider_observed_at': '2026-08-28T12:00:01.000Z',
  'source': 'detail',
};

const _accountId = '00000000-0000-4000-8000-000000000901';
const _instrumentId = '00000000-0000-4000-8000-000000000902';
const _previewId = '00000000-0000-4000-8000-000000000903';
const _commandId = '00000000-0000-4000-8000-000000000904';
const _orderId = '00000000-0000-4000-8000-000000000905';
const _meta = {'request_id': '00000000-0000-4000-8000-000000000906'};

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u9-loopback-token';
}

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
