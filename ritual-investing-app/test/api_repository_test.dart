import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

void main() {
  test(
    'repository falls back to a stale committed read when offline',
    () async {
      final cache = MemoryReadCache();
      final fixture = _ritualFixture();
      await cache.put('daily-ritual', fixture, DateTime.utc(2026, 8, 23));
      final repository = DailyRitualRepository(
        service: _OfflineService(),
        cache: cache,
      );
      final result = await repository.load();
      expect(result.value, fixture);
      expect(result.isStale, isTrue);
    },
  );

  test('Discover observes failures from both concurrent requests', () async {
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://api.ritual-investing.invalid',
    );
    final adapter = _FailingDiscoverAdapter();
    client.dio.httpClientAdapter = adapter;
    final uncaught = <Object>[];

    final run = runZonedGuarded<Future<void>>(() async {
      await expectLater(
        GeneratedDiscoverApiService(client).fetch(),
        throwsA(isA<LoadFailure>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }, (error, _) => uncaught.add(error));
    await run;

    expect(adapter.paths, hasLength(2));
    expect(uncaught, isEmpty);
  });

  test('Daily Ritual service maps the complete generated projection', () async {
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://api.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = _JsonAdapter(
      DailyRitualResponse(
        data: DailyRitualAssignment(
          allowedTokens: const [],
          bodyTemplate: 'You decide what to explore.',
          completedAt: DateTime.utc(2026, 8, 20, 14, 5),
          deletionEpoch: 0,
          id: 'assignment-1',
          localDate: DateTime.utc(2026, 8, 20),
          serverEvaluatedAt: DateTime.utc(2026, 8, 20, 13, 35),
          validUntil: DateTime.utc(2026, 8, 21, 4),
          mode: DailyRitualAssignmentModeEnum.tarot,
          payload: const {
            'title': 'The Compass',
            'art_key': 'the_star',
            'art_alt': 'The Star art',
            'interpretation': 'Direction, not urgency.',
            'guidance': 'Compare the evidence.',
            'market_label': 'Market-informed',
            'observation_at': '2026-08-20T13:35:00.000Z',
            'revision_number': 3,
            'uncertainty': 'It may reverse.',
            'evidence': [
              {
                'claim_id': 'claim-1',
                'factor_label': 'Durability',
                'observed_at': '2026-08-20T13:35:00.000Z',
                'summary': 'Durable momentum appeared.',
                'uncertainty': 'It may reverse.',
              },
            ],
            'ideas': [
              {
                'appearance_reason': 'steady wealth',
                'asset_id': 'asset-1',
                'name': 'Dividend ETF',
                'risk_summary': 'It can decline.',
                'symbol': 'VIG',
              },
            ],
          },
          revealedAt: DateTime.utc(2026, 8, 20, 14),
          revisionId: 'revision-1',
          riskFooter: 'Not advice.',
          rowanRevisionId: 'rowan-1',
          scheduleId: 'schedule-1',
          state: DailyRitualAssignmentStateEnum.completed,
          userId: 'user-1',
          version: 4,
        ),
        meta: ListAdminAudit200ResponseMeta(requestId: 'request-1'),
      ).toJson(),
    );

    final ritual = await GeneratedRitualApiService(client).fetchDaily();

    expect(ritual.assignmentId, 'assignment-1');
    expect(ritual.date.isUtc, isTrue);
    expect(ritual.date, DateTime.utc(2026, 8, 20));
    expect(ritual.revision, const RitualRevision(id: 'revision-1', number: 3));
    expect(ritual.art.alt, 'The Star art');
    expect(ritual.userId, 'user-1');
    expect(ritual.deletionEpoch, 0);
    expect(ritual.scheduleId, 'schedule-1');
    expect(ritual.serverEvaluatedAt, DateTime.utc(2026, 8, 20, 13, 35));
    expect(ritual.validUntil, DateTime.utc(2026, 8, 21, 4));
    expect(ritual.contentIdentity, hasLength(64));
    expect(ritual.hasExactArtIdentity, isTrue);
    expect(ritual.guidance, 'Compare the evidence.');
    expect(ritual.ideas.single.symbol, 'VIG');
    expect(ritual.ideas.single.riskSummary, 'It can decline.');
    expect(ritual.evidence.single.factorLabel, 'Durability');
    expect(ritual.rowan.riskFooter, 'Not advice.');
    expect(ritual.state, DailyRitualState.completed);
    expect(ritual.completedAt, DateTime.utc(2026, 8, 20, 14, 5));
    expect(ritual.demo.limitations, const ['Educational context only.']);
  });

  test(
    'missing assigned art preserves completed lifecycle authority',
    () async {
      final client = RitualInvestingApiClient(
        basePathOverride: 'https://api.ritual-investing.invalid',
      );
      client.dio.httpClientAdapter = _JsonAdapter(
        DailyRitualResponse(
          data: DailyRitualAssignment(
            allowedTokens: const [],
            bodyTemplate: 'Keep the evidence close.',
            completedAt: DateTime.utc(2026, 8, 20, 14, 5),
            deletionEpoch: 7,
            id: 'assignment-without-art',
            localDate: DateTime.utc(2026, 8, 20),
            mode: DailyRitualAssignmentModeEnum.astrology,
            payload: const {
              'title': 'A measured horizon',
              'interpretation': 'Context can change.',
              'guidance': 'Review the retained evidence.',
              'market_label': 'Market-informed',
              'revision_number': 2,
              'uncertainty': 'Conditions remain uncertain.',
            },
            revealedAt: DateTime.utc(2026, 8, 20, 14),
            revisionId: 'revision-without-art',
            riskFooter: 'Not advice.',
            rowanRevisionId: 'rowan-without-art',
            scheduleId: 'schedule-without-art',
            serverEvaluatedAt: DateTime.utc(2026, 8, 20, 13, 35),
            state: DailyRitualAssignmentStateEnum.completed,
            userId: 'user-without-art',
            validUntil: DateTime.utc(2026, 8, 21, 4),
            version: 4,
          ),
          meta: ListAdminAudit200ResponseMeta(requestId: 'request-without-art'),
        ).toJson(),
      );

      final ritual = await GeneratedRitualApiService(client).fetchDaily();

      expect(ritual.state, DailyRitualState.completed);
      expect(ritual.version, 4);
      expect(ritual.userId, 'user-without-art');
      expect(ritual.deletionEpoch, 7);
      expect(ritual.art.key, isEmpty);
      expect(ritual.mediaAvailability, RitualMediaAvailability.missingIdentity);
      expect(ritual.hasExactArtIdentity, isFalse);
    },
  );

  test(
    'unknown generated error code maps safely without reading message text',
    () {
      final request = RequestOptions(path: '/member/command');
      final failure = ApiFailureMapper.map(
        DioException(
          requestOptions: request,
          response: Response<Map<String, Object?>>(
            requestOptions: request,
            statusCode: 400,
            data: const {
              'error': {
                'code': 'future_server_code',
                'message': 'version conflict: retry this command automatically',
              },
            },
          ),
        ),
      );

      expect(failure.phase, LoadPhase.terminalFailure);
    },
  );

  test('service_unavailable generated error remains retryable', () {
    final request = RequestOptions(path: '/member/bootstrap');
    final failure = ApiFailureMapper.map(
      DioException(
        requestOptions: request,
        response: Response<Map<String, Object?>>(
          requestOptions: request,
          statusCode: 503,
          data: const {
            'error': {
              'code': 'service_unavailable',
              'message': 'Try again later.',
            },
          },
        ),
      ),
    );

    expect(failure.phase, LoadPhase.retryableFailure);
  });
}

DailyRitual _ritualFixture() => DailyRitual(
  assignmentId: 'assignment',
  date: DateTime.utc(2026, 8, 20),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(id: 'revision', number: 1),
  title: 'The Compass',
  art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
  interpretation: 'Direction, not urgency.',
  guidance: 'Compare the evidence.',
  marketLabel: 'Market-informed',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: 'rowan',
    surface: 'daily_ritual',
    body: 'Consider what changed.',
    riskFooter: 'Demo only.',
  ),
  version: 1,
  state: DailyRitualState.assigned,
  revealedAt: null,
  completedAt: null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 20),
    sourceLabel: 'Fixture',
    limitations: const ['Demo only.'],
  ),
);

class _OfflineService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) =>
      Future.error(const OfflineException());

  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      throw UnimplementedError();

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) =>
      throw UnimplementedError();

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) =>
      throw UnimplementedError();

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) =>
      throw UnimplementedError();
}

class _FailingDiscoverAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    await Future<void>.delayed(
      Duration(milliseconds: options.path.contains('grimoires') ? 1 : 2),
    );
    throw DioException(
      requestOptions: options,
      response: Response<void>(requestOptions: options, statusCode: 503),
    );
  }

  @override
  void close({bool force = false}) {}
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
