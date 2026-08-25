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
import 'package:ritual_investing_app/features/future_mirror/application/future_mirror_controller.dart';
import 'package:ritual_investing_app/features/future_mirror/data/repository.dart';
import 'package:ritual_investing_app/features/future_mirror/presentation/future_mirror_screen.dart';
import 'package:ritual_investing_app/features/intentions/application/intention_controller.dart';
import 'package:ritual_investing_app/features/intentions/data/repository.dart';
import 'package:ritual_investing_app/features/intentions/presentation/intention_screen.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member creates a personalized Intention and synchronous Future Mirror',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);
      await tester.pumpWidget(_FlowApp(harness));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('intentions-new')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('intention-title')))
            .controller
            ?.text,
        'Build a calm fund',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('intention-target-date')))
            .controller
            ?.text,
        '2027-08-25',
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('intention-review-create')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('intention-confirm-create')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Authoritative Demo Intention created'),
        findsOneWidget,
      );

      await _tapVisible(tester, find.text('Build a calm fund').first);
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('intention-open-future-mirror')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('never a predicted return'), findsWidgets);
      await _tapVisible(tester, find.byKey(const Key('future-mirror-review')));
      await _tapVisible(tester, find.byKey(const Key('future-mirror-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Future Mirror completed'), findsOneWidget);
      expect(
        find.textContaining('Source: Loopback Demo ledger'),
        findsOneWidget,
      );
      expect(find.text('Limitation: No real money moves.'), findsOneWidget);

      final intentionPost = harness.single('POST', '/v1/intentions');
      expect(intentionPost.authorization, 'Bearer u8-loopback-token');
      expect(intentionPost.idempotencyKey, 'u8-intention-key-1');
      expect(intentionPost.body, {
        'portfolio_id': _portfolioId,
        'target': {'currency': 'USD', 'minor_units': 500000},
        'target_date': '2027-08-25',
        'title': 'Build a calm fund',
      });
      final mirrorPost = harness.single(
        'POST',
        '/v1/intentions/$_intentionId/future-mirror',
      );
      expect(mirrorPost.authorization, 'Bearer u8-loopback-token');
      expect(mirrorPost.idempotencyKey, 'u8-mirror-key-0001');
      expect(mirrorPost.body, {
        'annual_return_bps': {'high': 4500, 'low': -2500, 'mid': 750},
        'monthly_contribution': {'currency': 'USD', 'minor_units': 10000},
        'name': 'Illustrative path',
      });
      expect(
        harness.requests.every(
          (request) => !RegExp(
            r'bank|broker|plaid|alpaca|provider|credential',
            caseSensitive: false,
          ).hasMatch('${request.path} ${request.rawBody}'),
        ),
        isTrue,
      );
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  if (vertical.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: vertical.last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _FlowApp extends StatefulWidget {
  const _FlowApp(this.harness);
  final _Harness harness;

  @override
  State<_FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<_FlowApp> {
  static const scope = CacheScope(accountId: 'u8-account', resetGeneration: 6);
  late final PendingCommandStore pending = PendingCommandStore(
    storage: _Storage(),
  );
  late final InvalidationBus bus = InvalidationBus();
  late final GeneratedPortfolioApiService portfolioService =
      GeneratedPortfolioApiService(widget.harness.client);
  late final PortfolioController portfolios = PortfolioController(
    repository: CachedPortfolioRepository(
      service: portfolioService,
      cache: MemoryReadCache(),
    ),
    bootstrapDefaultPortfolioId: _portfolioId,
    createKey: () => 'u8-portfolio-key-1',
  );
  late final IntentionController intentions =
      IntentionController(
        repository: CachedIntentionRepository(
          service: GeneratedIntentionApiService(widget.harness.client),
          cache: MemoryReadCache(),
        ),
        pendingStore: pending,
        invalidationBus: bus,
        scope: scope,
        createKey: () => 'u8-intention-key-1',
        now: () => DateTime.utc(2026, 8, 25),
      )..updateProfile(
        const SavedInvestorProfile(
          experience: InvestingExperience.newToInvesting,
          goal: InvestmentGoal.calmFund,
          horizon: InvestmentHorizon.short,
          risk: RiskComfort.high,
          contributionRhythm: ContributionRhythm.weekly,
          isDemo: true,
          version: 1,
        ),
      );
  late final FutureMirrorController mirror = FutureMirrorController(
    repository: CachedFutureMirrorRepository(
      service: GeneratedFutureMirrorApiService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
    pendingStore: pending,
    invalidationBus: bus,
    scope: scope,
    createKey: () => 'u8-mirror-key-0001',
    now: () => DateTime.utc(2026, 8, 25, 12),
    personalization: const MemberPersonalization(
      riskFraming: MemberRiskFraming.high,
      contributionRhythm: MemberContributionRhythm.weekly,
    ),
  );

  @override
  void dispose() {
    intentions.dispose();
    mirror.dispose();
    portfolios.dispose();
    unawaited(bus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Builder(
      builder: (context) => IntentionsScreen(
        portfolioId: _portfolioId,
        controller: intentions,
        onOpenIntention: (intentionId) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => IntentionDetailScreen(
              portfolioId: _portfolioId,
              intentionId: intentionId,
              controller: intentions,
              onOpenFutureMirror: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FutureMirrorScreen(
                    portfolioId: _portfolioId,
                    intentionId: intentionId,
                    controller: mirror,
                    intentionController: intentions,
                    portfolioController: portfolios,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Harness {
  _Harness._(this.server, this.client);

  final HttpServer server;
  final RitualInvestingApiClient client;
  final List<_Request> requests = [];
  bool intentionCreated = false;
  bool mirrorCreated = false;

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

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _serve() async {
    await for (final request in server) {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? null
          : jsonDecode(rawBody) as Map<String, dynamic>;
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          body: body,
          rawBody: rawBody,
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
      } else if (request.method == 'GET' &&
          (path.endsWith('/holdings') ||
              path.endsWith('/activity') ||
              path.endsWith('/snapshots'))) {
        _json(request, {'data': <Object?>[], 'meta': _collectionMeta});
      } else if (request.method == 'GET' && path == '/v1/intentions') {
        _json(request, {
          'data': [if (intentionCreated) _intention],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'POST' && path == '/v1/intentions') {
        intentionCreated = true;
        request.response.statusCode = HttpStatus.created;
        _json(request, {'data': _intention, 'meta': _meta});
      } else if (request.method == 'GET' &&
          path == '/v1/intentions/$_intentionId') {
        _json(request, {'data': _intention, 'meta': _meta});
      } else if (request.method == 'GET' &&
          path.endsWith('/future-mirror/latest') &&
          !mirrorCreated) {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('not_found'));
      } else if (request.method == 'POST' &&
          path == '/v1/intentions/$_intentionId/future-mirror') {
        mirrorCreated = true;
        _json(request, {'data': _mirror, 'meta': _meta});
      } else if (request.method == 'GET' && path.contains('/future-mirror')) {
        _json(request, {'data': _mirror, 'meta': _meta});
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('resource_not_found'));
      }
      await request.response.close();
    }
  }

  void _json(HttpRequest request, Object value) =>
      request.response.write(jsonEncode(value));
}

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.authorization,
    required this.idempotencyKey,
    required this.body,
    required this.rawBody,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? idempotencyKey;
  final Map<String, dynamic>? body;
  final String rawBody;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u8-loopback-token';
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

const _portfolioId = '00000000-0000-4000-8000-000000000891';
const _intentionId = '00000000-0000-4000-8000-000000000892';
const _mirrorId = '00000000-0000-4000-8000-000000000893';
const _transactionId = '00000000-0000-4000-8000-000000000894';
const _meta = {'request_id': '00000000-0000-4000-8000-000000000895'};
const _collectionMeta = {
  'request_id': '00000000-0000-4000-8000-000000000895',
  'has_more': false,
  'next_cursor': null,
};
const _demo = {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Loopback Demo ledger',
  'limitations': ['No real money moves.'],
};
const _portfolio = {
  'as_of_transaction_id': _transactionId,
  'cash': {'currency': 'USD', 'minor_units': 250000},
  'currency': 'USD',
  'demo': _demo,
  'id': _portfolioId,
  'is_default': true,
  'latest_valuation': {'currency': 'USD', 'minor_units': 250000},
  'ledger_watermark': 12,
  'name': 'Loopback Intentions Portfolio',
  'positions': <Object?>[],
  'status': 'active',
  'target_allocation': <Object?>[],
  'version': 3,
};
const _intention = {
  'demo': _demo,
  'id': _intentionId,
  'latest_projection_id': null,
  'portfolio_id': _portfolioId,
  'progress': {'currency': 'USD', 'minor_units': 0},
  'progress_bps': 0,
  'status': 'active',
  'target': {'currency': 'USD', 'minor_units': 500000},
  'target_date': '2027-08-25',
  'title': 'Build a calm fund',
  'version': 1,
};
const _mirror = {
  'assumptions': {
    'annual_return_bps': {'high': 4500, 'low': -2500, 'mid': 750},
    'monthly_contribution': {'currency': 'USD', 'minor_units': 10000},
    'name': 'Illustrative path',
  },
  'demo': _demo,
  'generated_at': '2026-08-25T12:00:00.000Z',
  'id': _mirrorId,
  'input_hash':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'intention_id': _intentionId,
  'ledger_watermark': 12,
  'model_version': 'ritual-demo-v1',
  'points': [
    {
      'date': '2027-08-25',
      'high': {'currency': 'USD', 'minor_units': 710000},
      'low': {'currency': 'USD', 'minor_units': 520000},
      'mid': {'currency': 'USD', 'minor_units': 620000},
    },
  ],
  'uncertainty': 'Illustrative Demo ranges only; never a guarantee.',
};

Map<String, Object?> _error(String code) => {
  'error': {
    'code': code,
    'field_errors': <Object?>[],
    'message': 'Not found',
    'request_id': _meta['request_id'],
    'retryable': false,
  },
};
