import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/funding/application/contribution_controller.dart';
import 'package:ritual_investing_app/features/funding/application/funding_source_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/orders/application/order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/repository.dart';
import 'package:ritual_investing_app/features/orders/presentation/order_screen.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/presentation/portfolio_screen.dart';
import 'package:ritual_investing_app/features/rebalancing/application/rebalance_controller.dart';
import 'package:ritual_investing_app/features/rebalancing/data/repository.dart';
import 'package:ritual_investing_app/features/rebalancing/presentation/rebalance_screen.dart';
import 'package:ritual_investing_app/features/recurring/application/recurring_plan_controller.dart';
import 'package:ritual_investing_app/features/recurring/data/repository.dart';
import 'package:ritual_investing_app/features/recurring/presentation/recurring_plan_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member explicitly confirms order, recurring plan, and rebalance',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);
      await tester.pumpWidget(_FlowApp(harness));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('open-demo-orders')));
      await tester.pumpAndSettle();
      expect(find.text('QPW · 1.250000 held'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('preview-order')));
      await tester.pumpAndSettle();
      expect(find.text('Review frozen Demo order'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      expect(find.text('Authoritative Demo receipt'), findsOneWidget);
      expect(
        find.text('Command $_orderCommandId · portfolio v8'),
        findsOneWidget,
      );
      expect(
        find.text('Demo ledger reconciled at watermark 12.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('open-recurring-plans')));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('review-recurring-create')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review recurring schedule'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const Key('confirm-recurring-create')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Authoritative Demo schedule created'),
        findsOneWidget,
      );
      expect(find.text('Authoritative schedules'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('open-rebalance')));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('preview-rebalance')));
      await tester.pumpAndSettle();
      expect(find.textContaining('BUY QPW'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('confirm-rebalance')));
      await tester.pumpAndSettle();
      expect(find.text('Authoritative rebalance receipt'), findsOneWidget);
      expect(find.textContaining('portfolio v9'), findsOneWidget);
      expect(
        find.text('Demo ledger reconciled at watermark 13.'),
        findsOneWidget,
      );

      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u7-loopback-token',
        ),
        isTrue,
      );
      expect(
        harness.single('/v1/portfolios/$_portfolioId/orders').idempotencyKey,
        'u7-order-key-0001',
      );
      expect(
        harness
            .single(
              '/v1/portfolios/$_portfolioId/recurring-plans',
              method: 'POST',
            )
            .idempotencyKey,
        'u7-recurring-key-1',
      );
      expect(
        harness
            .single('/v1/portfolios/$_portfolioId/rebalances')
            .idempotencyKey,
        'u7-rebalance-key-1',
      );
      for (final suffix in ['/holdings', '/activity', '/snapshots']) {
        expect(
          harness.requests
              .where((request) => request.path.endsWith(suffix))
              .length,
          greaterThanOrEqualTo(3),
          reason: '$suffix must be refetched after accepted ledger commands.',
        );
      }
      final wire = harness.requests
          .map((request) => '${request.path} ${request.body}')
          .join(' ')
          .toLowerCase();
      expect(
        wire,
        isNot(
          matches(
            RegExp(r'broker|bank_account|routing|plaid|alpaca|credential'),
          ),
        ),
      );
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

class _FlowApp extends StatefulWidget {
  const _FlowApp(this.harness);
  final _Harness harness;
  @override
  State<_FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<_FlowApp> {
  late final GeneratedPortfolioApiService portfolioService =
      GeneratedPortfolioApiService(widget.harness.client);
  late final PortfolioController portfolios = PortfolioController(
    repository: CachedPortfolioRepository(
      service: portfolioService,
      cache: MemoryReadCache(),
    ),
    bootstrapDefaultPortfolioId: _portfolioId,
    createKey: () => 'u7-portfolio-key-1',
  );
  late final CachedFundingRepository funding = CachedFundingRepository(
    service: portfolioService,
    cache: MemoryReadCache(),
  );
  late final FundingSourceController sources = FundingSourceController(
    repository: funding,
    createKey: () => 'u7-source-key-0001',
  );
  late final PendingCommandStore pending = PendingCommandStore(
    storage: _Storage(),
  );
  late final InvalidationBus bus = InvalidationBus();
  static const scope = CacheScope(accountId: 'u7-account', resetGeneration: 5);
  late final ContributionController contribution = ContributionController(
    repository: funding,
    portfolioController: portfolios,
    pendingStore: pending,
    invalidationBus: bus,
    scope: scope,
    createKey: () => 'u7-contribution-key',
    now: () => DateTime.utc(2026, 8, 25),
    rhythm: MemberContributionRhythm.monthly,
  );
  late final OrderController orders = OrderController(
    repository: OrderRepository(
      service: GeneratedOrderApiService(widget.harness.client),
    ),
    portfolioController: portfolios,
    pendingStore: pending,
    invalidationBus: bus,
    scope: scope,
    createKey: () => 'u7-order-key-0001',
    now: () => DateTime.utc(2026, 8, 25, 12),
  );
  late final RecurringPlanController recurring = RecurringPlanController(
    repository: RecurringPlanRepository(
      service: GeneratedRecurringPlanApiService(widget.harness.client),
    ),
    pendingStore: pending,
    scope: scope,
    createKey: () => 'u7-recurring-key-1',
    now: () => DateTime.utc(2026, 8, 25, 12),
    rhythm: MemberContributionRhythm.monthly,
    isFundingSourceActive: (sourceId) async {
      final result = await funding.loadSources();
      return !result.isStale &&
          result.value.items.any(
            (source) => source.id == sourceId && source.isActive,
          );
    },
  );
  late final RebalanceController rebalance = RebalanceController(
    repository: RebalanceRepository(
      service: GeneratedRebalanceApiService(widget.harness.client),
    ),
    portfolioController: portfolios,
    pendingStore: pending,
    invalidationBus: bus,
    scope: scope,
    createKey: () => 'u7-rebalance-key-1',
    now: () => DateTime.utc(2026, 8, 25, 12),
  );

  @override
  void dispose() {
    portfolios.dispose();
    sources.dispose();
    contribution.dispose();
    orders.dispose();
    recurring.dispose();
    rebalance.dispose();
    unawaited(bus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Builder(
      builder: (context) => PortfolioScreen(
        portfolioId: _portfolioId,
        portfolioController: portfolios,
        fundingSourceController: sources,
        contributionController: contribution,
        onOpenOrders: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderScreen(
              portfolioId: _portfolioId,
              controller: orders,
              portfolioController: portfolios,
            ),
          ),
        ),
        onOpenRecurringPlans: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecurringPlansScreen(
              portfolioId: _portfolioId,
              controller: recurring,
              portfolioController: portfolios,
              fundingSourceController: sources,
            ),
          ),
        ),
        onOpenRebalance: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RebalanceScreen(
              portfolioId: _portfolioId,
              controller: rebalance,
              portfolioController: portfolios,
            ),
          ),
        ),
      ),
    ),
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
  bool orderCommitted = false;
  bool recurringCreated = false;
  bool rebalanceCommitted = false;

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

  _Request single(String path, {String method = 'POST'}) =>
      requests.singleWhere(
        (request) => request.method == method && request.path == path,
      );

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
      if (request.method == 'GET' && path == '/v1/portfolios') {
        _json(request, {
          'data': [_portfolio],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'GET' &&
          path == '/v1/portfolios/$_portfolioId') {
        _json(request, {'data': _portfolio, 'meta': _meta});
      } else if (request.method == 'GET' && path.endsWith('/holdings')) {
        _json(request, {
          'data': [_holding],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'GET' && path.endsWith('/activity')) {
        _json(request, {'data': <Object?>[], 'meta': _collectionMeta});
      } else if (request.method == 'GET' && path.endsWith('/snapshots')) {
        _json(request, {'data': <Object?>[], 'meta': _collectionMeta});
      } else if (request.method == 'GET' &&
          path == '/v1/demo-funding-sources') {
        _json(request, {
          'data': [_source],
          'meta': _meta,
        });
      } else if (request.method == 'GET' && path == '/v1/orders') {
        _json(request, {
          'data': [if (orderCommitted) _order],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'POST' && path.endsWith('/order-previews')) {
        _json(request, {'data': _orderPreview, 'meta': _meta});
      } else if (request.method == 'POST' && path.endsWith('/orders')) {
        orderCommitted = true;
        _json(request, {'data': _orderReceipt, 'meta': _meta});
      } else if (request.method == 'GET' && path.endsWith('/recurring-plans')) {
        _json(request, {
          'data': [if (recurringCreated) _plan],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'POST' &&
          path.endsWith('/recurring-plans')) {
        recurringCreated = true;
        request.response.statusCode = HttpStatus.created;
        _json(request, {'data': _plan, 'meta': _meta});
      } else if (request.method == 'POST' &&
          path.endsWith('/rebalance-previews')) {
        _json(request, {'data': _rebalancePreview, 'meta': _meta});
      } else if (request.method == 'POST' && path.endsWith('/rebalances')) {
        rebalanceCommitted = true;
        _json(request, {'data': _rebalanceReceipt, 'meta': _meta});
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

  Map<String, Object?> get _portfolio => {
    'as_of_transaction_id': _transactionId,
    'cash': {'currency': 'USD', 'minor_units': 5000},
    'currency': 'USD',
    'demo': _demo,
    'id': _portfolioId,
    'is_default': true,
    'latest_valuation': {'currency': 'USD', 'minor_units': 10000},
    'ledger_watermark': rebalanceCommitted ? 13 : (orderCommitted ? 12 : 11),
    'name': 'Loopback Demo Portfolio',
    'positions': [_holding],
    'status': 'active',
    'target_allocation': [
      {'asset_id': _assetId, 'target_bps': 10000},
    ],
    'version': rebalanceCommitted ? 9 : (orderCommitted ? 8 : 7),
  };
}

const _portfolioId = '00000000-0000-4000-8000-000000000871';
const _sourceId = '00000000-0000-4000-8000-000000000872';
const _assetId = '00000000-0000-4000-8000-000000000873';
const _transactionId = '00000000-0000-4000-8000-000000000874';
const _orderPreviewId = '00000000-0000-4000-8000-000000000875';
const _orderId = '00000000-0000-4000-8000-000000000876';
const _orderCommandId = '00000000-0000-4000-8000-000000000877';
const _planId = '00000000-0000-4000-8000-000000000878';
const _rebalancePreviewId = '00000000-0000-4000-8000-000000000879';
const _rebalanceCommandId = '00000000-0000-4000-8000-000000000880';
const _meta = {'request_id': '00000000-0000-4000-8000-000000000881'};
const _collectionMeta = {
  'request_id': '00000000-0000-4000-8000-000000000881',
  'has_more': false,
  'next_cursor': null,
};
const _demo = {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Loopback Demo ledger',
  'limitations': ['No real money moves.'],
};
const _holding = {
  'as_of_transaction_id': _transactionId,
  'asset_id': _assetId,
  'ledger_watermark': 11,
  'market_value': {'currency': 'USD', 'minor_units': 2500},
  'quantity': {'scale': 6, 'value': '1.250000'},
  'symbol': 'QPW',
};
const _source = {
  'demo': _demo,
  'display_label': 'Moon Reserve (fictional)',
  'fictional_last4': '1108',
  'fixture_key': 'moon_reserve',
  'id': _sourceId,
  'status': 'active',
};
const _orderPreview = {
  'id': _orderPreviewId,
  'portfolio_id': _portfolioId,
  'portfolio_version': 7,
  'asset_id': _assetId,
  'symbol': 'QPW',
  'side': 'buy',
  'notional': {'currency': 'USD', 'minor_units': 2500},
  'quantity': {'value': '1.250000', 'scale': 6},
  'frozen_price': {'currency': 'USD', 'minor_units': 2000},
  'quote_snapshot_id': _transactionId,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'expires_at': '2026-08-25T12:15:00.000Z',
  'status': 'active',
  'demo': _demo,
};
const _order = {
  'id': _orderId,
  'portfolio_id': _portfolioId,
  'command_id': _orderCommandId,
  'asset_id': _assetId,
  'symbol': 'QPW',
  'side': 'buy',
  'status': 'accepted',
  'notional': {'currency': 'USD', 'minor_units': 2500},
  'quantity': null,
  'fill': {
    'quantity': {'value': '1.250000', 'scale': 6},
    'price': {'currency': 'USD', 'minor_units': 2000},
    'filled_at': '2026-08-25T12:01:00.000Z',
  },
  'demo': _demo,
};
const _orderReceipt = {
  'command_id': _orderCommandId,
  'status': 'committed',
  'portfolio_version': 8,
  'ledger_transaction_ids': [_transactionId],
  'summary': {'kind': 'order'},
  'projection_links': <Object?>[],
  'demo': _demo,
};
const _plan = {
  'id': _planId,
  'portfolio_id': _portfolioId,
  'type': 'contribution',
  'amount': {'currency': 'USD', 'minor_units': 2500},
  'frequency': 'monthly',
  'next_run_at': '2026-09-01T13:30:00.000Z',
  'status': 'active',
  'allocations': [
    {'asset_id': _assetId, 'weight_bps': 10000},
  ],
  'recent_runs': <Object?>[],
  'version': 1,
  'demo': _demo,
};
const _rebalancePreview = {
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
      'quantity': {'value': '0.125', 'scale': 3},
      'notional': {'currency': 'USD', 'minor_units': 2500},
    },
  ],
  'expires_at': '2026-08-25T12:15:00.000Z',
  'status': 'active',
  'demo': _demo,
};
const _rebalanceReceipt = {
  'command_id': _rebalanceCommandId,
  'status': 'committed',
  'portfolio_version': 9,
  'ledger_transaction_ids': [_transactionId],
  'summary': {'kind': 'rebalance'},
  'projection_links': <Object?>[],
  'demo': _demo,
};

class _Token implements AccessTokenProvider {
  const _Token();
  @override
  Future<String?> accessToken() async => 'u7-loopback-token';
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
