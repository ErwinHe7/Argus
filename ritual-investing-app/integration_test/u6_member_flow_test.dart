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
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/presentation/portfolio_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member reviews and confirms a provider-free Demo contribution',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);

      await tester.pumpWidget(_FlowApp(harness));
      await tester.pumpAndSettle();
      expect(find.textContaining('Provider-free Demo'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('review-contribution')),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('review-contribution')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing moves until you confirm.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-contribution')));
      await tester.pumpAndSettle();

      expect(find.text('Authoritative Demo receipt'), findsOneWidget);
      expect(find.textContaining(_commandId), findsOneWidget);
      expect(
        find.text('Demo ledger reconciled at watermark 7.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('portfolio-detail-name')),
        -500,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(r'$75.00'), findsOneWidget);
      expect(find.text(r'$97.00'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('demo contribution'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Valuation history'), findsOneWidget);
      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u6-loopback-token',
        ),
        isTrue,
      );
      final contribution = harness.requests.singleWhere(
        (request) => request.path.endsWith('/contributions'),
      );
      expect(contribution.idempotencyKey, 'u6-contribution-key');
      expect(jsonDecode(contribution.body), {
        'amount': {'currency': 'USD', 'minor_units': 2500},
        'source_id': _sourceId,
      });
      final wire = harness.requests
          .map((request) => '${request.path} ${request.body}')
          .join(' ')
          .toLowerCase();
      expect(
        wire,
        isNot(
          matches(
            RegExp(r'routing|account_number|card|credential|plaid|broker'),
          ),
        ),
      );
    },
  );
}

class _FlowApp extends StatefulWidget {
  const _FlowApp(this.harness);
  final _Harness harness;

  @override
  State<_FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<_FlowApp> {
  late final GeneratedPortfolioApiService service =
      GeneratedPortfolioApiService(widget.harness.client);
  late final PortfolioController portfolios = PortfolioController(
    repository: CachedPortfolioRepository(
      service: service,
      cache: MemoryReadCache(),
    ),
    bootstrapDefaultPortfolioId: _portfolioId,
    createKey: () => 'u6-portfolio-key',
  );
  late final CachedFundingRepository funding = CachedFundingRepository(
    service: service,
    cache: MemoryReadCache(),
  );
  late final FundingSourceController sources = FundingSourceController(
    repository: funding,
    createKey: () => 'u6-source-key',
  );
  late final InvalidationBus bus = InvalidationBus();
  late final ContributionController contribution = ContributionController(
    repository: funding,
    portfolioController: portfolios,
    pendingStore: PendingCommandStore(storage: _Storage()),
    invalidationBus: bus,
    scope: const CacheScope(accountId: 'u6-account', resetGeneration: 4),
    createKey: () => 'u6-contribution-key',
    now: () => DateTime.utc(2026, 8, 25),
    rhythm: MemberContributionRhythm.weekly,
  );

  @override
  void initState() {
    super.initState();
    unawaited(portfolios.load());
  }

  @override
  void dispose() {
    portfolios.dispose();
    sources.dispose();
    contribution.dispose();
    unawaited(bus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: PortfolioScreen(
      portfolioId: _portfolioId,
      portfolioController: portfolios,
      fundingSourceController: sources,
      contributionController: contribution,
    ),
  );
}

class _CapturedRequest {
  const _CapturedRequest(
    this.path,
    this.authorization,
    this.idempotencyKey,
    this.body,
  );
  final String path;
  final String? authorization;
  final String? idempotencyKey;
  final String body;
}

class _Harness {
  _Harness._(this.server, this.client);
  final HttpServer server;
  final RitualInvestingApiClient client;
  final List<_CapturedRequest> requests = [];
  bool committed = false;

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
        _CapturedRequest(
          request.uri.path,
          request.headers.value(HttpHeaders.authorizationHeader),
          request.headers.value('idempotency-key'),
          body,
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
        _json(request, {
          'data': [if (committed) _activity],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'GET' && path.endsWith('/snapshots')) {
        _json(request, {
          'data': [if (committed) _snapshot],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'GET' &&
          path == '/v1/demo-funding-sources') {
        _json(request, {
          'data': [_fundingSource],
          'meta': _meta,
        });
      } else if (request.method == 'POST' && path.endsWith('/contributions')) {
        committed = true;
        request.response.statusCode = HttpStatus.created;
        _json(request, {'data': _receipt, 'meta': _meta});
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
    'cash': {'currency': 'USD', 'minor_units': committed ? 7500 : 5000},
    'currency': 'USD',
    'demo': _demo,
    'id': _portfolioId,
    'is_default': true,
    'latest_valuation': {
      'currency': 'USD',
      'minor_units': committed ? 9700 : 7200,
    },
    'ledger_watermark': committed ? 7 : 6,
    'name': 'Loopback Demo Portfolio',
    'positions': [_holding],
    'status': 'active',
    'target_allocation': [
      {'asset_id': _assetId, 'target_bps': 10000},
    ],
    'version': committed ? 8 : 7,
  };

  Map<String, Object?> get _holding => {
    'as_of_transaction_id': _transactionId,
    'asset_id': _assetId,
    'ledger_watermark': committed ? 7 : 6,
    'market_value': {'currency': 'USD', 'minor_units': 2200},
    'quantity': {'scale': 6, 'value': '1.250000'},
    'symbol': 'QPW',
  };

  Map<String, Object?> get _activity => {
    'cash': {'currency': 'USD', 'minor_units': 2500},
    'demo': _demo,
    'description_code': 'demo_contribution',
    'effective_at': '2026-08-25T12:00:00.000Z',
    'id': _transactionId,
    'ledger_watermark': 7,
    'type': 'contribution',
  };

  Map<String, Object?> get _snapshot => {
    'as_of': '2026-08-25T12:00:00.000Z',
    'as_of_transaction_id': _transactionId,
    'cash': {'currency': 'USD', 'minor_units': 7500},
    'demo': _demo,
    'id': '00000000-0000-4000-8000-000000000866',
    'ledger_watermark': 7,
    'market_value': {'currency': 'USD', 'minor_units': 2200},
  };
}

const _portfolioId = '00000000-0000-4000-8000-000000000861';
const _sourceId = '00000000-0000-4000-8000-000000000862';
const _assetId = '00000000-0000-4000-8000-000000000863';
const _transactionId = '00000000-0000-4000-8000-000000000864';
const _commandId = '00000000-0000-4000-8000-000000000865';
const _meta = {'request_id': 'u6-request'};
const _collectionMeta = {
  'request_id': 'u6-request',
  'has_more': false,
  'next_cursor': null,
};
const _demo = {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Loopback Demo ledger',
  'limitations': ['No real money moves.'],
};
const _fundingSource = {
  'demo': _demo,
  'display_label': 'Moon Reserve (fictional)',
  'fictional_last4': '1108',
  'fixture_key': 'moon_reserve',
  'id': _sourceId,
  'status': 'active',
};
const _receipt = {
  'command_id': _commandId,
  'demo': _demo,
  'ledger_transaction_ids': [_transactionId],
  'portfolio_version': 8,
  'projection_links': <Object?>[],
  'status': 'committed',
  'summary': {'kind': 'contribution'},
};

class _Token implements AccessTokenProvider {
  const _Token();
  @override
  Future<String?> accessToken() async => 'u6-loopback-token';
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
