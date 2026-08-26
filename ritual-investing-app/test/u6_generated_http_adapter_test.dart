import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';

void main() {
  test(
    'U6 generated Dio adapters use real socket serialization and headers',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final client = RitualInvestingApiClient(
        basePathOverride: harness.baseUrl,
        interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
      );
      final service = GeneratedPortfolioApiService(client);
      final funding = service as FundingService;

      final list = await service.fetchList();
      final detail = await service.fetchDetail(_portfolioId);
      final holdings = await service.fetchHoldings(_portfolioId);
      final activity = await service.fetchActivity(_portfolioId);
      final snapshots = await service.fetchSnapshots(_portfolioId);
      await service.create(
        name: 'Moon Garden',
        idempotencyKey: 'portfolio-key',
      );
      await service.rename(
        portfolioId: _portfolioId,
        name: 'Steady Orbit',
        expectedVersion: 8,
      );
      await service.archive(portfolioId: _portfolioId, expectedVersion: 9);
      final sources = await funding.fetchSources();
      await funding.createSource(
        fixture: FundingFixture.constellationSavings,
        idempotencyKey: 'source-key',
      );
      await funding.deleteSource(_sourceId);
      final receipt = await funding.contribute(
        ContributionCommand(
          portfolioId: _portfolioId,
          sourceId: _sourceId,
          minorUnits: 2500,
          currency: PortfolioCurrency.usd,
          effectiveAt: DateTime.parse('2026-09-01T09:30:00-04:00'),
          idempotencyKey: 'contribution-key',
        ),
      );

      expect(list.items.single.isDefault, isTrue);
      expect(detail.targetAllocation.single.targetBps, 10000);
      expect(holdings.single.symbol, 'QPW');
      expect(activity.single.descriptionCode, 'demo_contribution');
      expect(snapshots.single.ledgerWatermark, 9);
      expect(sources.single.fictionalLast4, '1108');
      expect(receipt.ledgerTransactionIds, [_transactionId]);
      expect(
        harness.requests.every(
          (r) => r.authorization == 'Bearer u6-member-token',
        ),
        isTrue,
      );
      expect(
        harness.single('POST', '/v1/portfolios').idempotencyKey,
        'portfolio-key',
      );
      expect(
        harness.single('PATCH', '/v1/portfolios/$_portfolioId').ifMatch,
        '"v8"',
      );
      expect(
        harness.single('DELETE', '/v1/portfolios/$_portfolioId').ifMatch,
        '"v9"',
      );
      expect(harness.single('POST', '/v1/demo-funding-sources').body, {
        'fixture_key': 'constellation_savings',
      });
      expect(
        harness
            .single('POST', '/v1/portfolios/$_portfolioId/contributions')
            .body,
        {
          'amount': {'currency': 'USD', 'minor_units': 2500},
          'effective_at': '2026-09-01T13:30:00.000Z',
          'source_id': _sourceId,
        },
      );
    },
  );

  test(
    'unknown currency, non-Demo state, and forged fixture label fail terminal',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final client = RitualInvestingApiClient(
        basePathOverride: harness.baseUrl,
      );
      final service = GeneratedPortfolioApiService(client);

      for (final mode in [_Mode.unknownCurrency, _Mode.notDemo]) {
        harness.mode = mode;
        await expectLater(
          service.fetchList(),
          throwsA(
            isA<LoadFailure>().having(
              (f) => f.phase,
              'phase',
              LoadPhase.terminalFailure,
            ),
          ),
        );
      }
      harness.mode = _Mode.forgedFundingLabel;
      await expectLater(
        (service as FundingService).fetchSources(),
        throwsA(
          isA<LoadFailure>().having(
            (f) => f.phase,
            'phase',
            LoadPhase.terminalFailure,
          ),
        ),
      );

      harness.mode = _Mode.rejectedContribution;
      await expectLater(
        (service as FundingService).contribute(
          const ContributionCommand(
            portfolioId: _portfolioId,
            sourceId: _sourceId,
            minorUnits: 2500,
            currency: PortfolioCurrency.usd,
            effectiveAt: null,
            idempotencyKey: 'rejected-key',
          ),
        ),
        throwsA(
          isA<LoadFailure>().having(
            (f) => f.phase,
            'phase',
            LoadPhase.terminalFailure,
          ),
        ),
      );
    },
  );

  test('funding-source-in-use maps to its member-safe reason', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    harness.mode = _Mode.fundingSourceInUse;
    final service = GeneratedPortfolioApiService(
      RitualInvestingApiClient(basePathOverride: harness.baseUrl),
    ) as FundingService;

    await expectLater(
      service.deleteSource(_sourceId),
      throwsA(
        isA<FundingFailure>().having(
          (failure) => failure.reason,
          'reason',
          FundingFailureReason.fundingSourceInUse,
        ),
      ),
    );
  });
}

const _portfolioId = '00000000-0000-4000-8000-000000000801';
const _sourceId = '00000000-0000-4000-8000-000000000802';
const _assetId = '00000000-0000-4000-8000-000000000803';
const _transactionId = '00000000-0000-4000-8000-000000000804';

enum _Mode {
  normal,
  unknownCurrency,
  notDemo,
  forgedFundingLabel,
  rejectedContribution,
  fundingSourceInUse,
}

class _Request {
  const _Request(
    this.method,
    this.path,
    this.authorization,
    this.idempotencyKey,
    this.ifMatch,
    this.body,
  );
  final String method;
  final String path;
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
  _Request single(String method, String path) =>
      requests.singleWhere((r) => r.method == method && r.path == path);

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final body = text.isEmpty ? null : jsonDecode(text);
    requests.add(
      _Request(
        request.method,
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        request.headers.value('idempotency-key'),
        request.headers.value(HttpHeaders.ifMatchHeader),
        body,
      ),
    );
    final path = request.uri.path;
    final method = request.method;
    if (method == 'GET' && path == '/v1/portfolios') {
      return _json(request.response, {
        'data': [_portfolio],
        'meta': _collectionMeta,
      });
    }
    if (method == 'POST' && path == '/v1/portfolios') {
      return _json(request.response, {'data': _portfolio, 'meta': _meta}, 201);
    }
    if (method == 'GET' && path == '/v1/portfolios/$_portfolioId') {
      return _json(request.response, {'data': _portfolio, 'meta': _meta});
    }
    if (method == 'PATCH' && path == '/v1/portfolios/$_portfolioId') {
      return _json(request.response, {
        'data': {..._portfolio, 'name': 'Steady Orbit', 'version': 9},
        'meta': _meta,
      });
    }
    if (method == 'DELETE' && path == '/v1/portfolios/$_portfolioId') {
      return _empty(request.response);
    }
    if (method == 'GET' && path.endsWith('/holdings')) {
      return _json(request.response, {
        'data': [_holding],
        'meta': _collectionMeta,
      });
    }
    if (method == 'GET' && path.endsWith('/activity')) {
      return _json(request.response, {
        'data': [_activity],
        'meta': _collectionMeta,
      });
    }
    if (method == 'GET' && path.endsWith('/snapshots')) {
      return _json(request.response, {
        'data': [_snapshot],
        'meta': _collectionMeta,
      });
    }
    if (method == 'GET' && path == '/v1/demo-funding-sources') {
      return _json(request.response, {
        'data': [_funding],
        'meta': _meta,
      });
    }
    if (method == 'POST' && path == '/v1/demo-funding-sources') {
      return _json(request.response, {
        'data': {
          ..._funding,
          'fixture_key': 'constellation_savings',
          'display_label': 'Constellation Savings (fictional)',
          'fictional_last4': '2042',
        },
        'meta': _meta,
      }, 201);
    }
    if (method == 'DELETE' && path == '/v1/demo-funding-sources/$_sourceId') {
      if (mode == _Mode.fundingSourceInUse) {
        return _json(request.response, {
          'error': {
            'code': 'funding_source_in_use',
            'message': 'Remove its recurring plan before deleting this source.',
          },
        }, 409);
      }
      return _empty(request.response);
    }
    if (method == 'POST' && path.endsWith('/contributions')) {
      return _json(request.response, {
        'data': {
          ..._receipt,
          if (mode == _Mode.rejectedContribution) 'status': 'rejected',
        },
        'meta': _meta,
      }, 201);
    }
    return _json(request.response, {
      'error': {'code': 'resource_not_found', 'message': 'Not found'},
    }, 404);
  }

  Map<String, Object?> get _demo => {
    'is_demo': mode != _Mode.notDemo,
    'observed_at': '2026-08-25T12:00:00.000Z',
    'source_label': 'Deterministic Demo ledger',
    'limitations': ['No real money moves.'],
  };
  Map<String, Object?> get _portfolio => {
    'as_of_transaction_id': _transactionId,
    'cash': {'currency': 'USD', 'minor_units': 5000},
    'currency': mode == _Mode.unknownCurrency ? 'EUR' : 'USD',
    'demo': _demo,
    'id': _portfolioId,
    'is_default': true,
    'latest_valuation': {'currency': 'USD', 'minor_units': 7000},
    'ledger_watermark': 9,
    'name': 'Demo Portfolio',
    'positions': [_holding],
    'status': 'active',
    'target_allocation': [
      {'asset_id': _assetId, 'target_bps': 10000},
    ],
    'version': 8,
  };
  Map<String, Object?> get _holding => {
    'as_of_transaction_id': _transactionId,
    'asset_id': _assetId,
    'ledger_watermark': 9,
    'market_value': {'currency': 'USD', 'minor_units': 2000},
    'quantity': {'scale': 6, 'value': '1.250000'},
    'symbol': 'QPW',
  };
  Map<String, Object?> get _activity => {
    'cash': {'currency': 'USD', 'minor_units': 2500},
    'demo': _demo,
    'description_code': 'demo_contribution',
    'effective_at': '2026-08-25T12:00:00.000Z',
    'id': _transactionId,
    'ledger_watermark': 9,
    'type': 'contribution',
  };
  Map<String, Object?> get _snapshot => {
    'as_of': '2026-08-25T12:00:00.000Z',
    'as_of_transaction_id': _transactionId,
    'cash': {'currency': 'USD', 'minor_units': 5000},
    'demo': _demo,
    'id': '00000000-0000-4000-8000-000000000805',
    'ledger_watermark': 9,
    'market_value': {'currency': 'USD', 'minor_units': 2000},
  };
  Map<String, Object?> get _funding => {
    'demo': _demo,
    'display_label': mode == _Mode.forgedFundingLabel
        ? 'Real Bank'
        : 'Moon Reserve (fictional)',
    'fictional_last4': '1108',
    'fixture_key': 'moon_reserve',
    'id': _sourceId,
    'status': 'active',
  };
  Map<String, Object?> get _receipt => {
    'command_id': '00000000-0000-4000-8000-000000000806',
    'demo': _demo,
    'ledger_transaction_ids': [_transactionId],
    'portfolio_version': 9,
    'projection_links': [],
    'status': 'committed',
    'summary': {'kind': 'contribution'},
  };
}

const _meta = {'request_id': 'request-u6'};
const _collectionMeta = {
  'request_id': 'request-u6',
  'has_more': false,
  'next_cursor': null,
};

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
  Future<String?> accessToken() async => 'u6-member-token';
}
