import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/future_mirror/domain/model.dart';
import 'package:ritual_investing_app/features/intentions/domain/model.dart';

void main() {
  test(
    'U8 generated Dio adapters serialize exact provider-free contracts',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final client = RitualInvestingApiClient(
        basePathOverride: harness.baseUrl,
        interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
      );
      final intentions = GeneratedIntentionApiService(client);
      final mirrors = GeneratedFutureMirrorApiService(client);

      final page = await intentions.list(status: IntentionStatus.active);
      final created = await intentions.create(
        IntentionCreate(
          draft: IntentionDraft(
            portfolioId: _portfolioId,
            title: 'Moonlit reserve',
            targetMinor: 250000,
            targetDate: DateTime.utc(2028, 8, 24),
          ),
          idempotencyKey: 'intention-key-000001',
        ),
      );
      await intentions.get(_intentionId);
      await intentions.patch(
        IntentionPatch(
          intentionId: _intentionId,
          expectedVersion: 2,
          draft: IntentionDraft(
            portfolioId: _portfolioId,
            title: 'Moonlit reserve',
            targetMinor: 250000,
            targetDate: DateTime.utc(2028, 8, 24),
            status: IntentionStatus.completed,
          ),
        ),
      );
      await intentions.archive(_intentionId, 3);

      const draft = FutureMirrorDraft(
        name: 'Calm path',
        monthlyContributionMinor: 10000,
        lowReturnBps: -1000,
        midReturnBps: 400,
        highReturnBps: 2200,
      );
      final generated = await mirrors.generate(
        const FutureMirrorGenerate(
          intentionId: _intentionId,
          draft: draft,
          idempotencyKey: 'mirror-key-00000001',
        ),
      );
      final latest = await mirrors.getLatest(_intentionId);
      final historical = await mirrors.get(_intentionId, _mirrorId);

      expect(page.items.single.id, _intentionId);
      expect(created.portfolioId, _portfolioId);
      expect(generated.points.single.lowMinor, 260000);
      expect(latest?.ledgerWatermark, 12);
      expect(historical.id, _mirrorId);
      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u8-member-token',
        ),
        isTrue,
      );
      expect(harness.single('GET', '/v1/intentions').query['status'], 'active');
      expect(
        harness.single('POST', '/v1/intentions').idempotencyKey,
        'intention-key-000001',
      );
      expect(harness.single('POST', '/v1/intentions').body, {
        'portfolio_id': _portfolioId,
        'target': {'currency': 'USD', 'minor_units': 250000},
        'target_date': '2028-08-24',
        'title': 'Moonlit reserve',
      });
      expect(
        harness.single('PATCH', '/v1/intentions/$_intentionId').ifMatch,
        '"v2"',
      );
      expect(harness.single('PATCH', '/v1/intentions/$_intentionId').body, {
        'status': 'completed',
        'target': {'currency': 'USD', 'minor_units': 250000},
        'target_date': '2028-08-24',
        'title': 'Moonlit reserve',
      });
      expect(
        harness.single('DELETE', '/v1/intentions/$_intentionId').ifMatch,
        '"v3"',
      );
      expect(
        harness
            .single('POST', '/v1/intentions/$_intentionId/future-mirror')
            .idempotencyKey,
        'mirror-key-00000001',
      );
      expect(
        harness
            .single('POST', '/v1/intentions/$_intentionId/future-mirror')
            .body,
        {
          'annual_return_bps': {'high': 2200, 'low': -1000, 'mid': 400},
          'monthly_contribution': {'currency': 'USD', 'minor_units': 10000},
          'name': 'Calm path',
        },
      );
      expect(
        harness.requests.every(
          (request) =>
              request.path.startsWith('/v1/') &&
              !RegExp(
                r'bank|broker|payment|plaid|alpaca|provider',
                caseSensitive: false,
              ).hasMatch(request.path),
        ),
        isTrue,
      );
    },
  );

  test('malformed U8 generated socket responses fail closed', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final client = RitualInvestingApiClient(basePathOverride: harness.baseUrl);
    final intentions = GeneratedIntentionApiService(client);
    final mirrors = GeneratedFutureMirrorApiService(client);

    for (final mode in [_Mode.invalidProgress, _Mode.notDemo]) {
      harness.mode = mode;
      await expectLater(intentions.list(), throwsA(_terminalFailure));
    }
    for (final mode in [
      _Mode.foreignIntention,
      _Mode.invalidBands,
      _Mode.unorderedPoints,
      _Mode.badHash,
      _Mode.zeroWatermark,
      _Mode.unknownCurrency,
    ]) {
      harness.mode = mode;
      await expectLater(
        mirrors.get(_intentionId, _mirrorId),
        throwsA(_terminalFailure),
      );
    }
    harness.mode = _Mode.patchEchoMismatch;
    await expectLater(
      intentions.patch(
        IntentionPatch(
          intentionId: _intentionId,
          expectedVersion: 2,
          draft: IntentionDraft(
            portfolioId: _portfolioId,
            title: 'Moonlit reserve',
            targetMinor: 250000,
            targetDate: DateTime.utc(2028, 8, 24),
            status: IntentionStatus.completed,
          ),
        ),
      ),
      throwsA(_terminalFailure),
    );
    harness.mode = _Mode.assumptionEchoMismatch;
    await expectLater(
      mirrors.generate(
        const FutureMirrorGenerate(
          intentionId: _intentionId,
          draft: FutureMirrorDraft(
            name: 'Calm path',
            monthlyContributionMinor: 10000,
            lowReturnBps: -1000,
            midReturnBps: 400,
            highReturnBps: 2200,
          ),
          idempotencyKey: 'mirror-key-00000001',
        ),
      ),
      throwsA(_terminalFailure),
    );
  });

  test(
    'structured generated field errors use only allowlisted paths',
    () async {
      final harness = await _Harness.start()
        ..mode = _Mode.fieldErrors;
      addTearDown(harness.close);
      final mirrors = GeneratedFutureMirrorApiService(
        RitualInvestingApiClient(basePathOverride: harness.baseUrl),
      );

      await expectLater(
        mirrors.generate(
          const FutureMirrorGenerate(
            intentionId: _intentionId,
            draft: FutureMirrorDraft(
              name: 'Calm path',
              monthlyContributionMinor: 10000,
              lowReturnBps: -1000,
              midReturnBps: 400,
              highReturnBps: 2200,
            ),
            idempotencyKey: 'mirror-key-00000001',
          ),
        ),
        throwsA(
          isA<FutureMirrorValidationFailure>().having(
            (failure) => failure.fieldErrors,
            'allowlisted field errors',
            {
              FutureMirrorField.monthlyContribution: 'too_big',
              FutureMirrorField.highReturn: 'out_of_range',
            },
          ),
        ),
      );

      harness.mode = _Mode.fieldErrorsEnvelope;
      await expectLater(
        mirrors.generate(
          const FutureMirrorGenerate(
            intentionId: _intentionId,
            draft: FutureMirrorDraft(
              name: 'Calm path',
              monthlyContributionMinor: 10000,
              lowReturnBps: -1000,
              midReturnBps: 400,
              highReturnBps: 2200,
            ),
            idempotencyKey: 'mirror-key-00000002',
          ),
        ),
        throwsA(
          isA<FutureMirrorValidationFailure>().having(
            (failure) => failure.fieldErrors,
            'allowlisted money envelope',
            {FutureMirrorField.monthlyContribution: 'invalid_money'},
          ),
        ),
      );
    },
  );

  test('latest 404 is empty and activity conflict is typed', () async {
    final harness = await _Harness.start()
      ..mode = _Mode.latestMissing;
    addTearDown(harness.close);
    final mirrors = GeneratedFutureMirrorApiService(
      RitualInvestingApiClient(basePathOverride: harness.baseUrl),
    );
    expect(await mirrors.getLatest(_intentionId), isNull);

    harness.mode = _Mode.requiresActivity;
    await expectLater(
      mirrors.generate(
        const FutureMirrorGenerate(
          intentionId: _intentionId,
          draft: FutureMirrorDraft(
            name: 'Calm path',
            monthlyContributionMinor: 10000,
            lowReturnBps: -1000,
            midReturnBps: 400,
            highReturnBps: 2200,
          ),
          idempotencyKey: 'mirror-key-00000001',
        ),
      ),
      throwsA(
        isA<LoadFailure>().having(
          (failure) => failure.phase,
          'phase',
          LoadPhase.conflict,
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

enum _Mode {
  valid,
  foreignPortfolio,
  invalidProgress,
  notDemo,
  foreignIntention,
  invalidBands,
  unorderedPoints,
  badHash,
  zeroWatermark,
  unknownCurrency,
  fieldErrors,
  fieldErrorsEnvelope,
  latestMissing,
  requiresActivity,
  patchEchoMismatch,
  assumptionEchoMismatch,
}

class _Harness {
  _Harness._(this.server);

  final HttpServer server;
  final List<_Request> requests = [];
  _Mode mode = _Mode.valid;

  String get baseUrl => 'http://${server.address.address}:${server.port}';

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server);
    harness._serve();
    return harness;
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
          query: request.uri.queryParameters,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path;
      if ((mode == _Mode.fieldErrors || mode == _Mode.fieldErrorsEnvelope) &&
          request.method == 'POST' &&
          path.endsWith('/future-mirror')) {
        request.response.statusCode = HttpStatus.unprocessableEntity;
        request.response.write(
          jsonEncode(
            _error(
              'validation_failed',
              fieldErrors: mode == _Mode.fieldErrorsEnvelope
                  ? const [
                      {'path': 'monthly_contribution', 'code': 'invalid_money'},
                    ]
                  : const [
                      {
                        'path': 'monthly_contribution.minor_units',
                        'code': 'too_big',
                      },
                      {
                        'path': 'annual_return_bps.high',
                        'code': 'out_of_range',
                      },
                      {'path': 'private.unexpected', 'code': 'ignore_me'},
                    ],
            ),
          ),
        );
      } else if (mode == _Mode.requiresActivity &&
          request.method == 'POST' &&
          path.endsWith('/future-mirror')) {
        request.response.statusCode = HttpStatus.conflict;
        request.response.write(
          jsonEncode(_error('projection_requires_demo_activity')),
        );
      } else if (mode == _Mode.latestMissing &&
          path.endsWith('/future-mirror/latest')) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(_error('not_found')));
      } else if (request.method == 'GET' && path == '/v1/intentions') {
        request.response.write(
          jsonEncode({
            'data': [_intentionJson(mode)],
            'meta': {
              'has_more': false,
              'next_cursor': null,
              'request_id': _requestId,
            },
          }),
        );
      } else if (path.contains('/future-mirror')) {
        request.response.write(
          jsonEncode({
            'data': _mirrorJson(mode),
            'meta': {'request_id': _requestId},
          }),
        );
      } else if (request.method == 'DELETE') {
        request.response.statusCode = HttpStatus.noContent;
      } else {
        request.response.statusCode = request.method == 'POST'
            ? HttpStatus.created
            : HttpStatus.ok;
        request.response.write(
          jsonEncode({
            'data': _intentionJson(
              mode,
              status:
                  request.method == 'PATCH' && mode != _Mode.patchEchoMismatch
                  ? (body?['status'] as String?) ?? 'active'
                  : 'active',
            ),
            'meta': {'request_id': _requestId},
          }),
        );
      }
      await request.response.close();
    }
  }

  Future<void> close() => server.close(force: true);
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
  final Map<String, dynamic>? body;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u8-member-token';
}

Map<String, Object?> _intentionJson(_Mode mode, {String status = 'active'}) => {
  'demo': _demoJson(mode),
  'id': _intentionId,
  'latest_projection_id': _mirrorId,
  'portfolio_id': mode == _Mode.foreignPortfolio ? _foreignId : _portfolioId,
  'progress': {'currency': 'USD', 'minor_units': 50000},
  'progress_bps': mode == _Mode.invalidProgress ? 9999 : 2000,
  'status': status,
  'target': {'currency': 'USD', 'minor_units': 250000},
  'target_date': '2028-08-24',
  'title': 'Moonlit reserve',
  'version': 3,
};

Map<String, Object?> _mirrorJson(_Mode mode) => {
  'assumptions': {
    'annual_return_bps': mode == _Mode.invalidBands
        ? {'high': -1000, 'low': 2200, 'mid': 400}
        : {'high': 2200, 'low': -1000, 'mid': 400},
    'monthly_contribution': {
      'currency': 'USD',
      'minor_units': mode == _Mode.assumptionEchoMismatch ? 9999 : 10000,
    },
    'name': 'Calm path',
  },
  'demo': _demoJson(mode),
  'generated_at': '2026-08-25T12:00:00.000Z',
  'id': _mirrorId,
  'input_hash': mode == _Mode.badHash ? 'not-a-hash' : 'a' * 64,
  'intention_id': mode == _Mode.foreignIntention ? _foreignId : _intentionId,
  'ledger_watermark': mode == _Mode.zeroWatermark ? 0 : 12,
  'model_version': 'ritual-demo-v1',
  'points': [
    {
      'date': mode == _Mode.unorderedPoints ? '2028-09-01' : '2027-09-01',
      'high': {'currency': 'USD', 'minor_units': 310000},
      'low': {
        'currency': mode == _Mode.unknownCurrency ? 'EUR' : 'USD',
        'minor_units': 260000,
      },
      'mid': {'currency': 'USD', 'minor_units': 280000},
    },
    if (mode == _Mode.unorderedPoints)
      {
        'date': '2028-08-01',
        'high': {'currency': 'USD', 'minor_units': 320000},
        'low': {'currency': 'USD', 'minor_units': 270000},
        'mid': {'currency': 'USD', 'minor_units': 290000},
      },
  ],
  'uncertainty':
      'Illustrative Demo ranges only; not advice and never a guarantee.',
};

Map<String, Object?> _demoJson(_Mode mode) => {
  'is_demo': mode != _Mode.notDemo,
  'limitations': ['No real money moves.'],
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Deterministic Demo ledger',
};

Map<String, Object?> _error(
  String code, {
  List<Map<String, String>> fieldErrors = const [],
}) => {
  'error': {
    'code': code,
    'field_errors': fieldErrors,
    'message': 'Request could not be completed.',
    'request_id': _requestId,
    'retryable': false,
  },
};

const _requestId = '00000000-0000-4000-8000-000000000001';
const _portfolioId = '00000000-0000-4000-8000-000000000002';
const _intentionId = '00000000-0000-4000-8000-000000000020';
const _mirrorId = '00000000-0000-4000-8000-000000000021';
const _foreignId = '00000000-0000-4000-8000-000000000099';
