import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/bootstrap/member_feature_scope.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/generated_starpath_api_service.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerStarpathMemberFlowTests();
}

void registerStarpathMemberFlowTests() {
  testWidgets(
    'generated member boundary completes the factual eight-node path',
    (tester) async {
      late _StarpathHttpHarness harness;
      await tester.runAsync(() async {
        harness = await _StarpathHttpHarness.start();
      });
      addTearDown(harness.close);
      await tester.runAsync(harness.controller.load);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: StarpathScreen(controller: harness.controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Begin Starpath'), findsOneWidget);

      await tester.runAsync(harness.controller.start);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('starpath-node-1')), findsOneWidget);
      expect(harness.controller.state.snapshot?.nodes, hasLength(8));
      expect(harness.controller.state.snapshot?.currentNode?.nodeOrdinal, 1);

      final firstNode = find.byKey(const Key('starpath-node-1'));
      await tester.tap(
        find.descendant(of: firstNode, matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StarpathLessonScreen), findsOneWidget);

      await _scrollLessonTo(tester, 'Draw a card');
      await tester.tap(find.byKey(const Key('starpath-reveal-card')));
      await tester.pumpAndSettle();
      await _scrollLessonTo(tester, 'Reveal the financial fact');
      await tester.tap(find.byKey(const Key('starpath-reveal-fact')));
      await tester.pumpAndSettle();
      await _scrollLessonTo(tester, 'Test what you understand');
      await tester.tap(find.byKey(const Key('starpath-open-check')));
      await tester.pumpAndSettle();
      await _scrollLessonTo(tester, 'Guaranteed return');
      await tester.runAsync(() => harness.controller.answer('option-b-1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not quite yet.'), findsOneWidget);
      expect(harness.controller.state.snapshot?.currentNode?.nodeOrdinal, 1);
      expect(find.textContaining('life', findRichText: true), findsNothing);

      await tester.ensureVisible(find.text('Ownership interest'));
      await tester.runAsync(() => harness.controller.answer('option-a-1'));
      await tester.pumpAndSettle();
      expect(harness.controller.state.snapshot?.currentNode?.nodeOrdinal, 2);
      await tester.tap(find.byTooltip('Close activity'));
      await tester.pumpAndSettle();

      for (var ordinal = 2; ordinal <= 8; ordinal += 1) {
        await tester.runAsync(
          () => harness.controller.answer('option-a-$ordinal'),
        );
        await tester.pump();
      }

      final snapshot = harness.controller.state.snapshot!;
      expect(snapshot.progress?.currentNodeOrdinal, 9);
      expect(snapshot.currentNode, isNull);
      expect(
        snapshot.nodes.every(
          (node) => node.state == StarpathNodeState.completed,
        ),
        isTrue,
      );
      expect(find.byKey(const Key('starpath-node-8')), findsOneWidget);
      expect(find.byKey(const Key('starpath-node-9')), findsNothing);
      expect(harness.answerMutations, 9);
      expect(
        harness.commandKeys.toSet(),
        hasLength(harness.commandKeys.length),
      );
      expect(harness.requests.every((request) => request.authorized), isTrue);
      expect(
        harness.serializedCommandBodies,
        isNot(
          matches(
            RegExp(r'holding|balance|order|birth|astrolog|security_preference'),
          ),
        ),
      );

      final requestsBeforeRowan = harness.requests.length;
      harness.controller.revealRowan(8);
      expect(harness.requests, hasLength(requestsBeforeRowan));
      expect(harness.controller.state.rowanNodeOrdinal, 8);
    },
  );

  test(
    'same-key replay is stable and a different stale key conflicts',
    () async {
      final harness = await _StarpathHttpHarness.start();
      addTearDown(harness.close);
      final service = harness.service;

      final started = await service.start(idempotencyKey: 'start-replay-key');
      final node = started.currentNode!;
      final command = StarpathAnswerCommand(
        attemptKind: StarpathAttemptKind.node,
        sessionId: started.session!.id,
        manifestId: started.authority.manifestId,
        revisionId: node.revisionId,
        questionId: node.knowledgeCheck.id,
        optionId: 'option-b-1',
      );
      final first = await service.answer(
        idempotencyKey: 'answer-replay-key',
        version: started.version,
        command: command,
      );
      final replay = await service.answer(
        idempotencyKey: 'answer-replay-key',
        version: started.version,
        command: command,
      );

      expect(replay.version, first.version);
      expect(replay.progress?.currentNodeOrdinal, 1);
      expect(harness.answerMutations, 1);
      await expectLater(
        service.answer(
          idempotencyKey: 'different-stale-key',
          version: started.version,
          command: command,
        ),
        throwsA(isA<StarpathConflict>()),
      );
      expect(harness.answerMutations, 1);
    },
  );

  test('beta and production fixtures derive the exact branch contracts', () {
    final beta = MemberNavigationPolicy.fromBootstrap(
      _bootstrap(
        environment: MemberReleaseEnvironment.beta,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.discover,
          MemberBranchCapability.coven,
          MemberBranchCapability.you,
        },
      ),
    );
    final production = MemberNavigationPolicy.fromBootstrap(
      _bootstrap(
        environment: MemberReleaseEnvironment.production,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.you,
        },
      ),
    );

    expect(beta.branches, const [
      MemberBranch.ritual,
      MemberBranch.starpath,
      MemberBranch.discover,
      MemberBranch.coven,
      MemberBranch.you,
    ]);
    expect(production.branches, const [
      MemberBranch.ritual,
      MemberBranch.starpath,
      MemberBranch.you,
    ]);
    expect(production.redirectFor('/discover/assets/example'), '/starpath');
    expect(production.redirectFor('/coven/founders/example'), '/starpath');
  });
}

Future<void> _scrollLessonTo(WidgetTester tester, String text) async {
  for (
    var attempt = 0;
    attempt < 8 && find.text(text).evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await tester.pump();
  }
  expect(find.text(text), findsOneWidget);
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

MemberBootstrap _bootstrap({
  required MemberReleaseEnvironment environment,
  required Set<MemberBranchCapability> enabled,
}) => MemberBootstrap(
  accountId: 'starpath-integration-member',
  onboarding: const MemberOnboardingGate.complete(),
  serverTime: DateTime.utc(2026, 8, 30, 12),
  contractVersion: 'member-branch-capabilities-v1',
  themePreference: MemberThemePreference.system,
  branchCapabilities: MemberNavigationCapabilities(
    schemaVersion: 'member-branch-capabilities-v1',
    capabilityVersion: 17,
    environment: environment,
    evaluatedAt: DateTime.utc(2026, 8, 30, 11),
    expiresAt: DateTime.utc(2026, 8, 30, 13),
    enabled: enabled,
  ),
);

class _StarpathHttpHarness {
  _StarpathHttpHarness._({
    required this.server,
    required this.service,
    required this.controller,
    required this.previousHttpOverrides,
  });

  static const _token = 'starpath-integration-token';
  static const _requestId = '00000000-0000-4000-8000-000000000901';

  final HttpServer server;
  final GeneratedStarpathApiService service;
  final StarpathController controller;
  final HttpOverrides? previousHttpOverrides;
  final List<_ObservedRequest> requests = [];
  final List<String> commandKeys = [];
  final Map<String, Map<String, Object?>> _replays = {};
  var _started = false;
  var _version = 0;
  var _currentOrdinal = 1;
  var _answerMutations = 0;
  var _keySequence = 0;
  Map<String, Object?>? _answer;
  String? _commandEffect;

  int get answerMutations => _answerMutations;
  String get serializedCommandBodies => requests
      .where((request) => request.body.isNotEmpty)
      .map((request) => jsonEncode(request.body))
      .join(' ')
      .toLowerCase();

  static Future<_StarpathHttpHarness> start() async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [
        RitualAuthInterceptor(tokenProvider: const _FixedTokenProvider()),
      ],
    );
    final service = GeneratedStarpathApiService(client);
    late _StarpathHttpHarness harness;
    final controller = StarpathController(
      repository: StarpathRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
      createKey: () => 'starpath-command-${++harness._keySequence}',
    );
    harness = _StarpathHttpHarness._(
      server: server,
      service: service,
      controller: controller,
      previousHttpOverrides: previousHttpOverrides,
    );
    unawaited(harness._serve());
    return harness;
  }

  Future<void> _serve() async {
    await for (final request in server) {
      final bodyText = await utf8.decoder.bind(request).join();
      final body = bodyText.isEmpty
          ? <String, Object?>{}
          : Map<String, Object?>.from(jsonDecode(bodyText) as Map);
      final key = request.headers.value('idempotency-key');
      requests.add(
        _ObservedRequest(
          method: request.method,
          path: request.uri.path,
          authorized:
              request.headers.value(HttpHeaders.authorizationHeader) ==
              'Bearer $_token',
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;

      if (request.method == 'GET' && request.uri.path == '/v1/starpath') {
        await _write(request, _envelope(_snapshot()));
        continue;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/v1/starpath/sessions' &&
          key != null) {
        commandKeys.add(key);
        final replay = _replays['start:$key'];
        if (replay != null) {
          await _write(request, replay);
          continue;
        }
        _started = true;
        _version = 1;
        _commandEffect = 'started';
        final response = _envelope(_snapshot());
        _replays['start:$key'] = response;
        await _write(request, response);
        continue;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/v1/starpath/answers' &&
          key != null) {
        commandKeys.add(key);
        final replay = _replays['answer:$key'];
        if (replay != null) {
          await _write(request, replay);
          continue;
        }
        if (request.headers.value('if-match') != '"v$_version"') {
          await _writeError(request, 'starpath_progress_conflict');
          continue;
        }
        _answerMutations += 1;
        _version += 1;
        final correct = body['option_id'] == 'option-a-$_currentOrdinal';
        _answer = {
          'is_correct': correct,
          'explanation': correct
              ? 'That repeats the reviewed definition.'
              : 'A positive return is never guaranteed.',
        };
        _commandEffect = correct ? 'lesson_completed' : 'wrong_answer';
        if (correct) _currentOrdinal = (_currentOrdinal + 1).clamp(1, 9);
        final response = _envelope(_snapshot());
        _replays['answer:$key'] = response;
        await _write(request, response);
        continue;
      }

      request.response.statusCode = HttpStatus.notFound;
      await _write(request, {
        'error': {'code': 'resource_not_found', 'message': 'Not found'},
      });
    }
  }

  Map<String, Object?> _snapshot() => {
    'availability': _started ? 'available' : 'not_started',
    'version': _version,
    'authority': {
      'capability_version': 17,
      'manifest_id': 'manifest-starpath-v1',
      'manifest_version': 'starpath-v1',
      'policy_version': 'starpath-no-advice-v1',
      'environment': 'beta',
      'jurisdiction': 'US',
    },
    'session': _started
        ? {
            'id': 'session-starpath-v1',
            'state': _currentOrdinal == 9 ? 'closed' : 'active',
            'started_at': '2026-08-30T10:00:00.000Z',
            'last_action_at': '2026-08-30T10:01:00.000Z',
            'explicit_start': true,
            'replacement_of_session_id': null,
          }
        : null,
    'theme': _started
        ? {
            'id': 'theme-starpath-v1',
            'key': 'walk-the-stars',
            'title': 'Walk the Stars',
            'horoscope_frame':
                'Celestial imagery is a memory frame, not a forecast.',
            'factual_focus': 'Learn reviewed investment definitions.',
            'accessible_label':
                'A non-predictive downward factual learning path.',
          }
        : null,
    'progress': _started
        ? {
            'current_node_ordinal': _currentOrdinal,
            'version': _version,
            'updated_at': '2026-08-30T10:01:00.000Z',
          }
        : null,
    'nodes': List.generate(8, (index) {
      final ordinal = index + 1;
      final state = !_started
          ? 'locked'
          : ordinal < _currentOrdinal
          ? 'completed'
          : ordinal == _currentOrdinal
          ? 'current'
          : 'locked';
      return {
        'node_ordinal': ordinal,
        'pathway_ordinal': (index ~/ 2) + 1,
        'pathway_position': (index % 2) + 1,
        'state': state,
        'lesson_id': 'lesson-$ordinal',
        'revision_id': 'revision-$ordinal',
        'title': 'Star lesson $ordinal',
        'guide': {
          'tarot_key': 'the-star',
          'accessible_label': 'The Star, used only as a memory aid.',
        },
        'mythic_mnemonic':
            'Picture a steady star marking a definition, never an outcome.',
        'factual_summary':
            'A share generally represents an ownership interest in an issuer.',
        'factual_sections': [
          {
            'ordinal': 1,
            'kind': 'fact',
            'heading': 'Ownership units',
            'body': 'Common stock generally represents an ownership interest.',
            'uncertainty': 'Rights vary by security and governing documents.',
            'observed_at': '2026-08-29T00:00:00.000Z',
            'evidence': [
              {
                'ordinal': 1,
                'canonical_url': 'https://www.investor.gov/',
                'source_title': 'Stocks',
                'publisher': 'Investor.gov',
                'source_observed_at': '2026-08-29T00:00:00.000Z',
                'effective_at': null,
                'retrieved_at': '2026-08-29T00:00:00.000Z',
                'current_until': '2027-08-29T00:00:00.000Z',
                'claim_summary': 'A stock can represent an ownership interest.',
              },
            ],
          },
        ],
        'material_limitations': 'Share classes and rights differ.',
        'risk_context': 'Market value may fall, including to zero.',
        'recall_prompt': 'What does a share generally represent?',
        'rowan_explanation': 'A reviewed restatement of the definition.',
        'knowledge_check': {
          'id': 'question-$ordinal',
          'prompt': 'Which statement is factual?',
          'options': [
            {
              'id': 'option-a-$ordinal',
              'ordinal': 1,
              'label': 'Ownership interest',
            },
            {
              'id': 'option-b-$ordinal',
              'ordinal': 2,
              'label': 'Guaranteed return',
            },
          ],
        },
      };
    }),
    'recall': null,
    'command_effect': _commandEffect,
    'answer': _answer,
  };

  Map<String, Object?> _envelope(Map<String, Object?> data) => {
    'data': data,
    'meta': {'request_id': _requestId},
  };

  Future<void> _write(HttpRequest request, Map<String, Object?> value) async {
    request.response.write(jsonEncode(value));
    await request.response.close();
  }

  Future<void> _writeError(HttpRequest request, String code) async {
    request.response.statusCode = HttpStatus.conflict;
    await _write(request, {
      'error': {'code': code, 'message': 'Reload authoritative progress.'},
    });
  }

  Future<void> close() async {
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  }
}

class _FixedTokenProvider implements AccessTokenProvider {
  const _FixedTokenProvider();

  @override
  Future<String?> accessToken() async => _StarpathHttpHarness._token;
}

class _ObservedRequest {
  const _ObservedRequest({
    required this.method,
    required this.path,
    required this.authorized,
    required this.body,
  });

  final String method;
  final String path;
  final bool authorized;
  final Map<String, Object?> body;
}
