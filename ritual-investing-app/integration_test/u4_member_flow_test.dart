import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';

import 'support/u4_http_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'generated HTTP ritual stays authoritative through immersive Evidence and Starpath',
    (tester) async {
      late U4HttpHarness harness;
      await tester.runAsync(() async {
        harness = await U4HttpHarness.start();
      });
      addTearDown(harness.close);

      await tester.pumpWidget(_U4FlowApp(harness: harness));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leonidas-sequence-start')), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);

      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily-ritual-immersive')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Ready to hold'), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsNothing);

      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(DailyRitualStageSpec.sealHitKey)),
      );
      await tester.pump(const Duration(seconds: 5, milliseconds: 1));
      await tester.pump();
      await hold.up();
      await tester.pumpAndSettle();

      expect(find.text('Direction, not urgency.'), findsOneWidget);
      expect(find.byKey(const Key('ritual-complete')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsNothing);
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.revealed,
      );

      await tester.tap(find.byKey(const Key('ritual-complete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.completed,
      );

      await tester.tap(find.byKey(const Key('leonidas-evidence')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo Research Desk'), findsOneWidget);
      expect(
        find.textContaining('Provider-free evidence note'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ritual-evidence-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily-ritual-immersive')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);

      await tester.tap(find.byKey(const Key('leonidas-starpath')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('u5-starpath-destination')), findsOneWidget);

      await tester.runAsync(() async {
        final assignment = await GeneratedRitualApiService(harness.client)
            .fetchAssignment(u4AssignmentId);
        expect(assignment.state, DailyRitualState.completed);
      });
      _expectTransportBoundary(harness);
    },
  );
}

void _expectTransportBoundary(U4HttpHarness harness) {
  expect(harness.requests, isNotEmpty);
  expect(
    harness.requests.every(
      (request) => request.authorization == 'Bearer u4-local-member-token',
    ),
    isTrue,
  );
  final transitions = harness.requests.where(
    (request) => request.uri.path.endsWith('/transition'),
  );
  expect(transitions, hasLength(2));
  final reveal = transitions.singleWhere(
    (request) =>
        (jsonDecode(request.body) as Map<String, dynamic>)['to'] == 'revealed',
  );
  final complete = transitions.singleWhere(
    (request) =>
        (jsonDecode(request.body) as Map<String, dynamic>)['to'] == 'completed',
  );
  expect(reveal.ifMatch, '"v1"');
  expect(complete.ifMatch, '"v2"');
  expect(jsonDecode(reveal.body), {'from': 'assigned', 'to': 'revealed'});
  expect(jsonDecode(complete.body), {'from': 'revealed', 'to': 'completed'});
  expect(
    harness.requests.where(
      (request) => request.uri.path == '/v1/rituals/$u4AssignmentId/evidence',
    ),
    hasLength(1),
  );

  final serialized = harness.requests
      .map((request) => '${request.uri} ${request.body}')
      .join(' ')
      .toLowerCase();
  expect(serialized, isNot(contains('client_prompt')));
  expect(serialized, isNot(contains('snapshot')));
  expect(
    serialized,
    isNot(matches(RegExp(r'plaid|brokerage|banking|finance'))),
  );
}

class _U4FlowApp extends StatefulWidget {
  const _U4FlowApp({required this.harness});

  final U4HttpHarness harness;

  @override
  State<_U4FlowApp> createState() => _U4FlowAppState();
}

class _U4FlowAppState extends State<_U4FlowApp> {
  bool _starpathOpened = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.harness.ritualController.load());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: _starpathOpened
          ? const Center(
              child: Text(
                'Starpath destination',
                key: Key('u5-starpath-destination'),
              ),
            )
          : DailyRitualScreen(
              controller: widget.harness.ritualController,
              onOpenCoven: () {},
              onOpenSearch: () {},
              onOpenBriefings: () {},
              onToggleTheme: () {},
              onOpenStarpath: () => setState(() => _starpathOpened = true),
              leonidasVoice: const _ImmediateLeonidasVoice(),
              prepareExactMedia: (_) async => true,
            ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Ritual',
          ),
          NavigationDestination(icon: Icon(Icons.stars), label: 'Starpath'),
        ],
      ),
    ),
  );
}

class _ImmediateLeonidasVoice implements LeonidasVoice {
  const _ImmediateLeonidasVoice();

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}
}
