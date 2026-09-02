import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/features/asset_codex/application/controller.dart';
import 'package:ritual_investing_app/features/asset_codex/presentation/asset_codex_screen.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';

import 'support/u4_http_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'generated HTTP flow reveals evidence, Codex, search/save/compare, and non-blocking Rowan',
    (tester) async {
      late U4HttpHarness harness;
      await tester.runAsync(() async {
        harness = await U4HttpHarness.start();
      });
      addTearDown(harness.close);

      await tester.pumpWidget(_U4FlowApp(harness: harness));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ritual-reveal')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ritual-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('Direction, not urgency.'), findsOneWidget);
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.revealed,
      );

      await tester.tap(find.text('Market-informed Demo evidence'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo Research Desk'), findsOneWidget);
      expect(
        find.textContaining('Provider-free evidence note'),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.byKey(const Key('ritual-evidence-sheet'))),
      ).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('ritual-complete')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('ritual-complete')));
      await tester.pumpAndSettle();
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.completed,
      );
      expect(
        harness.ritualController.historyState.value?.items.single.state,
        DailyRitualState.completed,
      );

      await tester.scrollUntilVisible(
        find.text('VIG'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('VIG'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-codex-screen')), findsOneWidget);
      expect(find.text('Vigilant Demo ETF'), findsOneWidget);
      expect(find.text('PRACTICAL INTERPRETATION'), findsOneWidget);

      await tester.tap(find.byKey(const Key('asset-evidence')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo Research Desk'), findsOneWidget);
      expect(
        find.textContaining('Provider-free evidence note'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('asset-compare')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('asset-compare')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codex-search-field')), 'pe');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PEER · Patient Demo Fund'));
      await tester.pumpAndSettle();
      expect(find.text('Compared research'), findsOneWidget);
      expect(find.textContaining(u4PeerRevisionId), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('asset-save')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('asset-save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.byKey(const Key('asset-save')));
      await tester.pumpAndSettle();
      expect(find.text('Save research'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('rowan-explain')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('rowan-explain')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your research remains available'),
        findsOneWidget,
      );
      expect(find.text('VIG'), findsOneWidget);

      harness.rowanUnavailable = false;
      await tester.tap(find.byKey(const Key('rowan-explain')));
      await tester.pumpAndSettle();
      expect(
        find.text('Use the published evidence to compare uncertainty.'),
        findsOneWidget,
      );

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
  final reveal = harness.requests.singleWhere(
    (request) => request.uri.path.endsWith('/reveal'),
  );
  final complete = harness.requests.singleWhere(
    (request) => request.uri.path.endsWith('/complete'),
  );
  expect(reveal.ifMatch, '"v1"');
  expect(complete.ifMatch, '"v2"');

  final comparison = harness.requests.singleWhere(
    (request) => request.uri.path == '/v1/assets/compare',
  );
  expect(jsonDecode(comparison.body), {
    'asset_ids': [u4AssetId, u4PeerId],
  });
  final save = harness.requests.singleWhere(
    (request) =>
        request.method == 'PUT' &&
        request.uri.path == '/v1/me/saved-assets/$u4AssetId',
  );
  expect(jsonDecode(save.body), {
    'source_id': u4AssignmentId,
    'source_kind': 'ritual',
  });

  final search = harness.requests.singleWhere(
    (request) => request.uri.path == '/v1/search',
  );
  expect(search.uri.queryParameters['q'], 'pe');
  expect(
    search.uri.queryParameters['kinds'],
    'asset,circle_template,coven,grimoire',
  );
  final rowan = harness.requests.where(
    (request) => request.uri.path == '/v1/rowan/counsel',
  );
  expect(rowan, hasLength(2));
  expect(rowan.last.uri.queryParameters, {
    'surface': 'asset_codex',
    'context_code': 'asset',
    'resource_id': u4AssetId,
  });

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
  AssetCodexController? _assetController;

  @override
  void initState() {
    super.initState();
    unawaited(widget.harness.ritualController.load());
  }

  @override
  void dispose() {
    _assetController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: _assetController != null
        ? AssetCodexScreen(
            controller: _assetController!,
            rowanController: widget.harness.rowanController,
            searchController: widget.harness.searchController,
            personalization: const MemberPersonalization(
              explanationDepth: MemberExplanationDepth.guided,
              ritualVoice: MemberRitualVoice.practical,
              riskFraming: MemberRiskFraming.high,
            ),
          )
        : Scaffold(
            body: DailyRitualScreen(
              controller: widget.harness.ritualController,
              onOpenCoven: () {},
              onToggleTheme: () {},
              onOpenAsset: (id) {
                final controller = widget.harness.assetController(assetId: id);
                setState(() => _assetController = controller);
                unawaited(controller.load());
              },
              personalization: const MemberPersonalization(
                explanationDepth: MemberExplanationDepth.guided,
                ritualVoice: MemberRitualVoice.practical,
                riskFraming: MemberRiskFraming.high,
              ),
            ),
          ),
  );
}
