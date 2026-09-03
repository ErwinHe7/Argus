import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:test/test.dart';

const requestId = '018f3c2a-4b67-7a89-8abc-1234567890ab';

void main() {
  test('decodes retained response and error envelopes with future fields', () {
    final response = MemberAccountResponse.fromJson({
      'data': {
        'status': 'active',
        'deletion_epoch': 0,
        'profile': null,
        'preferences': null,
        'onboarding': null,
        'investor_profile': null,
        'astrology_profile': null,
        'future_server_field': true,
      },
      'meta': {'request_id': requestId, 'future_meta_field': true},
    });
    expect(response.meta.requestId, requestId);
    expect(response.data.status, MemberAccountStatusEnum.active);

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

    final response = await SessionApi(client.dio).bootstrapSession();

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
    expect(
      response.data?.data.branchCapabilities.environment,
      MemberBranchCapabilitiesEnvironmentEnum.beta,
    );
    expect(response.data?.data.branchCapabilities.branches, [
      'ritual',
      'starpath',
      'discover',
      'coven',
      'you',
    ]);
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

  test('decodes server-owned Daily Ritual day authority', () {
    final response = DailyRitualResponse.fromJson({
      'data': _dailyRitualAssignmentData(),
      'meta': {'request_id': requestId},
    });

    expect(
      response.data.toJson(),
      containsPair('server_evaluated_at', '2026-11-01T16:00:00.000Z'),
    );
    expect(
      response.data.toJson(),
      containsPair('valid_until', '2026-11-02T05:00:00.000Z'),
    );
    expect(response.data.localDate, DateTime.parse('2026-11-01'));
  });

  test('sends the adjacent Ritual transition with If-Match', () async {
    final adapter = _RecordingAdapter(data: _dailyRitualAssignmentData());
    final dio = Dio()..httpClientAdapter = adapter;

    await RitualsApi(dio).transitionRitual(
      assignmentId: '018f3c2a-4b67-7a89-8abc-123456789021',
      ifMatch: '"v1"',
      transitionRitualRequest: TransitionRitualRequest(
        from: TransitionRitualRequestFromEnum.assigned,
        to: TransitionRitualRequestToEnum.revealed,
      ),
    );

    expect(adapter.requests.single.method, 'POST');
    expect(
      adapter.requests.single.path,
      '/v1/rituals/018f3c2a-4b67-7a89-8abc-123456789021/transition',
    );
    expect(adapter.requests.single.headers['if-match'], '"v1"');
    expect(jsonDecode(adapter.requests.single.data as String), {
      'from': 'assigned',
      'to': 'revealed',
    });
  });

  test(
    'binds manual order confirmation to preview and idempotency header',
    () async {
      final adapter = _RecordingAdapter(
        data: {
          'id': '018f3c2a-4b67-7a89-8abc-123456789001',
          'account_id': '018f3c2a-4b67-7a89-8abc-123456789002',
          'operation': 'place',
          'target_order_id': null,
          'order_id': null,
          'state': 'ambiguous',
          'ambiguous': true,
          'created_at': '2026-08-28T12:00:00.000Z',
          'updated_at': '2026-08-28T12:00:01.000Z',
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final response = await BrokerageOrdersApi(dio).placeWebullOrder(
        accountId: '018f3c2a-4b67-7a89-8abc-123456789002',
        idempotencyKey: 'member-device-key-0001',
        confirmPlaceBrokerageOrder: ConfirmPlaceBrokerageOrder(
          confirmed: true,
          previewId: '018f3c2a-4b67-7a89-8abc-123456789003',
          intent: PlaceBrokerageOrderIntent(
            instrumentId: '018f3c2a-4b67-7a89-8abc-123456789004',
            limitPrice: '10.25',
            orderType: PlaceBrokerageOrderIntentOrderTypeEnum.limit,
            quantity: '1',
            side: PlaceBrokerageOrderIntentSideEnum.buy,
            timeInForce: PlaceBrokerageOrderIntentTimeInForceEnum.day,
          ),
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        '/v1/brokerage/accounts/018f3c2a-4b67-7a89-8abc-123456789002/orders',
      );
      expect(
        adapter.requests.single.headers['idempotency-key'],
        'member-device-key-0001',
      );
      expect(adapter.requests.single.data, contains('"confirmed":true'));
      expect(adapter.requests.single.data, contains('"preview_id"'));
      expect(
        response.data?.data.state,
        BrokerageOrderCommandStateEnum.ambiguous,
      );
    },
  );

  test(
    'requests an atomic provider-authoritative order list refresh',
    () async {
      final adapter = _RecordingAdapter(
        data: {
          'account_id': '018f3c2a-4b67-7a89-8abc-123456789002',
          'state': 'empty',
          'provider_observed_at': '2026-08-28T12:00:00.000Z',
          'fetched_at': '2026-08-28T12:00:01.000Z',
          'expires_at': '2026-08-28T12:01:01.000Z',
          'orders': <Object?>[],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      await BrokerageOrdersApi(dio).listWebullOrders(
        accountId: '018f3c2a-4b67-7a89-8abc-123456789002',
        refresh: 'true',
      );

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.queryParameters['refresh'], 'true');
    },
  );

  test('decodes the complete eight-node Starpath member snapshot', () {
    final response = StarpathSnapshotResponse.fromJson({
      'data': _starpathSnapshotData(),
      'meta': {'request_id': requestId},
    });

    expect(response.data.nodes, hasLength(8));
    expect(response.data.authority.manifestVersion, '2026.08.30.1');
    expect(response.data.nodes.first.revisionId, 'revision-1');
    expect(
      response
          .data
          .nodes
          .first
          .factualSections
          .single
          .evidence
          .single
          .sourceObservedAt,
      DateTime.parse('2026-08-29T12:00:00.000Z'),
    );
    expect(
      response
          .data
          .nodes
          .first
          .factualSections
          .single
          .evidence
          .single
          .currentUntil,
      DateTime.parse('2026-11-29T12:00:00.000Z'),
    );
    expect(
      response.data.nodes.first.knowledgeCheck.options.first.toJson(),
      isNot(contains('is_correct')),
    );
  });

  test('preserves Starpath forward compatibility through enum fallbacks', () {
    final data = _starpathSnapshotData();
    data['availability'] = 'future_availability';
    (data['authority']! as Map<String, Object?>)['environment'] =
        'future_environment';
    ((data['nodes']! as List<Object?>).first!
            as Map<String, Object?>)['state'] =
        'future_state';

    final response = StarpathSnapshotResponse.fromJson({
      'data': data,
      'meta': {'request_id': requestId},
    });

    expect(
      response.data.availability,
      StarpathSnapshotAvailabilityEnum.unknownDefaultOpenApi,
    );
    expect(
      response.data.authority.environment,
      StarpathAuthorityEnvironmentEnum.unknownDefaultOpenApi,
    );
    expect(
      response.data.nodes.first.state,
      StarpathNodeStateEnum.unknownDefaultOpenApi,
    );
  });

  test('rejects incomplete Starpath revision and evidence records', () {
    final missingRevision = _starpathSnapshotData();
    ((missingRevision['nodes']! as List<Object?>).first!
            as Map<String, Object?>)
        .remove('revision_id');

    expect(
      () => StarpathSnapshotResponse.fromJson({
        'data': missingRevision,
        'meta': {'request_id': requestId},
      }),
      throwsA(isA<CheckedFromJsonException>()),
    );

    final missingEvidenceDate = _starpathSnapshotData();
    final firstNode =
        (missingEvidenceDate['nodes']! as List<Object?>).first!
            as Map<String, Object?>;
    final firstSection =
        (firstNode['factual_sections']! as List<Object?>).first!
            as Map<String, Object?>;
    ((firstSection['evidence']! as List<Object?>).first!
            as Map<String, Object?>)
        .remove('retrieved_at');

    expect(
      () => StarpathSnapshotResponse.fromJson({
        'data': missingEvidenceDate,
        'meta': {'request_id': requestId},
      }),
      throwsA(isA<CheckedFromJsonException>()),
    );
  });

  test('starts Starpath without a body and sends an idempotency key', () async {
    final adapter = _RecordingAdapter(data: _starpathSnapshotData());
    final dio = Dio()..httpClientAdapter = adapter;

    final response = await StarpathApi(
      dio,
    ).startOrResumeStarpath(idempotencyKey: 'starpath-start-0001');

    expect(response.data?.data.nodes, hasLength(8));
    expect(adapter.requests.single.path, '/v1/starpath/sessions');
    expect(adapter.requests.single.method, 'POST');
    expect(
      adapter.requests.single.headers['idempotency-key'],
      'starpath-start-0001',
    );
    expect(adapter.requests.single.data, isNull);
  });

  test('binds Starpath answers to idempotency and snapshot version', () async {
    final adapter = _RecordingAdapter(data: _starpathSnapshotData());
    final dio = Dio()..httpClientAdapter = adapter;
    final command = AnswerStarpathQuestion(
      attemptKind: AnswerStarpathQuestionAttemptKindEnum.node,
      manifestId: 'manifest-1',
      optionId: 'option-1-a',
      questionId: 'question-1',
      revisionId: 'revision-1',
      sessionId: 'session-1',
    );

    await StarpathApi(dio).answerStarpathQuestion(
      idempotencyKey: 'starpath-answer-0001',
      ifMatch: '"v3"',
      answerStarpathQuestion: command,
    );

    expect(adapter.requests.single.path, '/v1/starpath/answers');
    expect(adapter.requests.single.headers['if-match'], '"v3"');
    expect(
      adapter.requests.single.headers['idempotency-key'],
      'starpath-answer-0001',
    );
    expect(
      jsonDecode(adapter.requests.single.data as String),
      command.toJson(),
    );
  });

  test('binds recall skips to idempotency and snapshot version', () async {
    final adapter = _RecordingAdapter(data: _starpathSnapshotData());
    final dio = Dio()..httpClientAdapter = adapter;
    final command = SkipStarpathRecall(sessionId: 'session-1');

    await StarpathApi(dio).skipStarpathRecall(
      idempotencyKey: 'starpath-skip-0001',
      ifMatch: '"v3"',
      skipStarpathRecall: command,
    );

    expect(adapter.requests.single.path, '/v1/starpath/recall/skip');
    expect(adapter.requests.single.headers['if-match'], '"v3"');
    expect(
      adapter.requests.single.headers['idempotency-key'],
      'starpath-skip-0001',
    );
    expect(
      jsonDecode(adapter.requests.single.data as String),
      command.toJson(),
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.data});

  final Map<String, Object?>? data;
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
        'data': data ?? _defaultData(options.path),
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

Map<String, Object?> _defaultData(String path) {
  if (path == '/v1/session/bootstrap') {
    return {
      'astrology_profile': null,
      'investor_profile': null,
      'member': {
        'created_at': null,
        'deletion_epoch': 0,
        'deletion_requested_at': null,
        'status': 'active',
        'updated_at': null,
        'user_id': '018f3c2a-4b67-7a89-8abc-123456789001',
      },
      'onboarding': null,
      'preferences': null,
      'profile': null,
      'server_time': '2026-08-28T12:00:00.000Z',
      'branch_capabilities': {
        'schema_version': 'member-branch-capabilities-v1',
        'capability_version': 1,
        'environment': 'beta',
        'evaluated_at': '2026-08-28T12:00:00.000Z',
        'expires_at': '2026-08-28T12:05:00.000Z',
        'branches': ['ritual', 'starpath', 'discover', 'coven', 'you'],
      },
    };
  }
  if (path == '/v1/preferences') {
    return {
      'deletion_epoch': 0,
      'locale': 'en-US',
      'ritual_mode': 'tarot',
      'theme_mode': 'dark',
      'timezone': 'UTC',
      'user_id': '018f3c2a-4b67-7a89-8abc-123456789001',
      'version': 4,
    };
  }
  return const {};
}

Map<String, Object?> _dailyRitualAssignmentData() {
  return {
    'id': '018f3c2a-4b67-7a89-8abc-123456789021',
    'user_id': '018f3c2a-4b67-7a89-8abc-123456789001',
    'deletion_epoch': 0,
    'local_date': '2026-11-01',
    'server_evaluated_at': '2026-11-01T16:00:00.000Z',
    'valid_until': '2026-11-02T05:00:00.000Z',
    'mode': 'tarot',
    'schedule_id': '018f3c2a-4b67-7a89-8abc-123456789022',
    'revision_id': '018f3c2a-4b67-7a89-8abc-123456789023',
    'rowan_revision_id': null,
    'state': 'assigned',
    'revealed_at': null,
    'completed_at': null,
    'version': 1,
    'payload': {
      'title': 'Strength',
      'art_key': 'strength',
      'art_alt': 'Strength tarot card',
      'interpretation': 'Patience is the stronger path.',
    },
    'body_template': null,
    'allowed_tokens': null,
    'risk_footer': null,
  };
}

Map<String, Object?> _starpathSnapshotData() {
  return {
    'availability': 'available',
    'version': 3,
    'authority': {
      'capability_version': 9,
      'manifest_id': 'manifest-1',
      'manifest_version': '2026.08.30.1',
      'policy_version': 'policy-1',
      'environment': 'beta',
      'jurisdiction': 'US',
    },
    'session': {
      'id': 'session-1',
      'state': 'active',
      'started_at': '2026-08-30T12:00:00.000Z',
      'last_action_at': '2026-08-30T12:01:00.000Z',
      'explicit_start': true,
      'replacement_of_session_id': null,
    },
    'theme': {
      'id': 'theme-1',
      'key': 'walk-the-stars',
      'title': 'Walk the Stars',
      'horoscope_frame': 'A mnemonic sky map, not a forecast.',
      'factual_focus': 'How diversified funds work.',
      'accessible_label': 'Constellation pathway',
    },
    'progress': {
      'current_node_ordinal': 1,
      'version': 3,
      'updated_at': '2026-08-30T12:01:00.000Z',
    },
    'nodes': List<Object?>.generate(8, (index) {
      final ordinal = index + 1;
      return {
        'node_ordinal': ordinal,
        'pathway_ordinal': (index ~/ 2) + 1,
        'pathway_position': (index % 2) + 1,
        'state': ordinal == 1 ? 'current' : 'locked',
        'lesson_id': 'lesson-$ordinal',
        'revision_id': 'revision-$ordinal',
        'title': 'Star lesson $ordinal',
        'guide': {
          'tarot_key': 'major-$ordinal',
          'accessible_label': 'Guide card $ordinal',
        },
        'mythic_mnemonic': 'A memory aid only; it predicts nothing.',
        'factual_summary': 'A factual description of the instrument.',
        'factual_sections': [
          {
            'ordinal': 1,
            'kind': 'fact',
            'heading': 'What it is',
            'body': 'A pooled investment holds underlying assets.',
            'uncertainty': 'Holdings and prices change over time.',
            'observed_at': '2026-08-29T12:00:00.000Z',
            'evidence': [
              {
                'ordinal': 1,
                'canonical_url': 'https://www.investor.gov/example',
                'source_title': 'Investor bulletin',
                'publisher': 'Investor.gov',
                'source_observed_at': '2026-08-29T12:00:00.000Z',
                'effective_at': '2026-08-01T00:00:00.000Z',
                'retrieved_at': '2026-08-30T11:00:00.000Z',
                'current_until': '2026-11-29T12:00:00.000Z',
                'claim_summary': 'Defines the instrument and its limits.',
              },
            ],
          },
        ],
        'material_limitations': 'Fees and tracking can vary.',
        'risk_context': 'Market value can rise or fall.',
        'recall_prompt': 'Recall one factual limitation.',
        'rowan_explanation':
            'Rowan explains the fact without a recommendation.',
        'knowledge_check': {
          'id': 'question-$ordinal',
          'prompt': 'Which statement is factual?',
          'options': [
            {
              'id': 'option-$ordinal-a',
              'ordinal': 1,
              'label': 'It pools assets.',
            },
            {
              'id': 'option-$ordinal-b',
              'ordinal': 2,
              'label': 'It predicts returns.',
            },
          ],
        },
      };
    }),
    'recall': null,
    'command_effect': null,
    'answer': null,
  };
}
