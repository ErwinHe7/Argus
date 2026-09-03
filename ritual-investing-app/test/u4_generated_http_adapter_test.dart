import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/rowan/domain/model.dart';

import '../integration_test/support/u4_http_harness.dart';

void main() {
  test(
    'all U4 generated adapters use the local member HTTP contract',
    () async {
      final harness = await U4HttpHarness.start();
      addTearDown(harness.close);

      await harness.ritualController.load();
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.assigned,
      );

      final ritualService = GeneratedRitualApiService(harness.client);
      final assignment = await ritualService.fetchAssignment(u4AssignmentId);
      expect(assignment.assignmentId, u4AssignmentId);
      expect(await ritualService.fetchEvidence(u4AssignmentId), hasLength(1));

      await harness.ritualController.reveal();
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.revealed,
      );
      await harness.ritualController.loadHistory();
      expect(harness.ritualController.historyState.phase, LoadPhase.ready);
      expect(
        harness.ritualController.historyState.value?.items.single.state,
        DailyRitualState.revealed,
      );
      await harness.ritualController.complete();
      expect(
        harness.ritualController.state.value?.state,
        DailyRitualState.completed,
      );
      await harness.ritualController.loadHistory();
      expect(
        harness.ritualController.historyState.value?.items.single.state,
        DailyRitualState.completed,
      );

      final asset = harness.assetController();
      addTearDown(asset.dispose);
      await asset.load();
      expect(asset.state.value?.id, u4AssetId);
      expect(asset.state.value?.revisionId, u4AssetRevisionId);
      expect(
        asset.state.value?.detailedEvidence.single.publisher,
        'Demo Research Desk',
      );
      expect(asset.state.value?.metrics.single.priceMinor, 12345);

      await asset.toggleSaved();
      expect(asset.state.value?.saved, isTrue);
      await asset.toggleSaved();
      expect(asset.state.value?.saved, isFalse);
      await asset.compareWith(const [u4PeerId]);
      expect(asset.comparisonState.phase, LoadPhase.ready);
      expect(
        asset.comparisonState.value?.items.last.asset.revisionId,
        u4PeerRevisionId,
      );

      harness.searchController.updateQuery('pe');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(harness.searchController.state.phase, LoadPhase.ready);
      expect(harness.searchController.state.value?.items.single.id, u4PeerId);

      await harness.rowanController.explain(RowanRequest.assetCodex(u4AssetId));
      expect(harness.rowanController.state.phase, LoadPhase.retryableFailure);
      harness.rowanUnavailable = false;
      await harness.rowanController.explain(RowanRequest.assetCodex(u4AssetId));
      expect(harness.rowanController.state.phase, LoadPhase.ready);
      expect(
        harness.rowanController.state.value?.scriptRevisionId,
        '00000000-0000-4000-8000-000000000408',
      );

      _expectGeneratedTransport(harness);
    },
  );
}

void _expectGeneratedTransport(U4HttpHarness harness) {
  expect(
    harness.requests.every(
      (request) => request.authorization == 'Bearer u4-local-member-token',
    ),
    isTrue,
  );
  final transitions = harness.requests.where(
    (request) => request.uri.path.endsWith('/transition'),
  );
  expect(
    transitions
        .singleWhere(
          (request) => (jsonDecode(request.body) as Map)['to'] == 'revealed',
        )
        .ifMatch,
    '"v1"',
  );
  expect(
    transitions
        .singleWhere(
          (request) => (jsonDecode(request.body) as Map)['to'] == 'completed',
        )
        .ifMatch,
    '"v2"',
  );

  final comparison = harness.requests.singleWhere(
    (request) => request.uri.path == '/v1/assets/compare',
  );
  expect(jsonDecode(comparison.body), {
    'assetIds': [u4AssetId, u4PeerId],
  });
  final save = harness.requests.singleWhere(
    (request) =>
        request.method == 'POST' &&
        request.uri.path == '/v1/saved/asset/$u4AssetId',
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
  final rowan = harness.requests
      .where((request) => request.uri.path == '/v1/rowan/asset_codex/asset')
      .last;
  expect(rowan.uri.queryParameters, isEmpty);

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
